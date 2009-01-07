require 'rubygems'
require 'zlib'
require 'digest/sha1'
require 'yaml'

require 'git_store/blob'
require 'git_store/tree'
require 'git_store/handlers'
require 'git_store/pack'

# GitStore implements a versioned data store based on the revision
# management system git. You can store object hierarchies as nested
# hashes, which will be mapped on the directory structure of a git
# repository.
#
# GitStore supports transactions, so that updates to the store either
# fail or succeed completely.
#
# GitStore manages concurrent access by a file locking scheme. So only
# one process can start a transaction at one time. This is implemented
# by locking the `refs/head/<branch>.lock` file, which is also respected
# by the git binary.
#
# A regular commit should be atomic by the nature of git, as the only
# critical part is writing the 40 bytes SHA1 hash of the commit object
# to the file `refs/head/<branch>`, which is done atomically by the
# operating system.
#
# So reading a repository should be always consistent in a git
# repository. The head of a branch points to a commit object, which in
# turn points to a tree object, which itself is a snapshot of the
# GitStore at commit time. All involved objects are keyed by their
# SHA1 value, so there is no chance for another process to write to
# the same files.
#
class GitStore
  include Enumerable

  attr_reader :path, :index, :root, :branch, :lock_file, :head, :packs

  # Initialize a store.
  def initialize(path, branch = 'master')
    @path   = path.chomp('/')
    @branch = branch
    @root   = Tree.new(self)
    
    load_packs("#{path}/.git/objects/pack")
    load
  end

  # The path to the current head file.
  def head_path
    "#{path}/.git/refs/heads/#{branch}"
  end

  # The path to the object file for given id.
  def object_path(id)
    "#{path}/.git/objects/#{ id[0...2] }/#{ id[2..39] }"
  end

  # Read the id of the head commit.
  #
  # Returns the object id of the last commit.
  def read_head
    File.read(head_path).strip if File.exists?(head_path)
  end

  # Read an object for the specified path.
  #
  # Use multiple arguments or a string with slashes.
  def [](*args)
    root[*args]
  end

  # Write an object to the specified path.
  #
  # Use multiple arguments or a string with slashes.
  def []=(*args)
    value = args.pop
    root[*args] = value
  end

  # Delete the specified path.
  #
  # Use multiple arguments or a string with slashes.
  def delete(*args)
    root.delete(*args)
  end

  # Returns the store as a hash tree.
  def to_hash
    root.to_hash
  end

  # Inspect the store.
  def inspect
    "#<GitStore #{path} #{branch} #{root.to_hash.inspect}>"
  end

  # Iterate over all values found in this store.
  def each(&block)
    root.each(&block)
  end

  # Has our store been changed on disk?
  def changed?
    head != read_head
  end

  def refresh!
    load if changed?
  end

  # Load the current head version from repository. 
  def load
    if @head = read_head
      commit = get_object(head)[0]
      root.id = commit.split(/[ \n]/, 3)[1].strip
      root.data = get_object(root.id)[0]
      root.load_from_store
    end
  end

  # Reload the store, if it has been changed on disk.
  def refresh!
    load if changed?
  end

  # Do we have a current transacation?
  def in_transaction?
    Thread.current['git_store_lock']
  end

  # All changes made inside a transaction are atomic. If some
  # exception occurs the transaction will be rolled back.
  #
  # Example:
  #   store.transaction { store['a'] = 'b' }
  #
  def transaction(message = "")
    start_transaction
    result = yield
    commit message
    
    result
  rescue
    rollback
    raise
  ensure
    finish_transaction
  end

  # Start a transaction.
  #
  # Tries to get lock on lock file, reload the this store if
  # has changed in the repository.
  def start_transaction
    file = open("#{head_path}.lock", "w")
    file.flock(File::LOCK_EX)
    
    Thread.current['git_store_lock'] = file
    
    load if changed?
  end

  # Restore the state of the store.
  #
  # Any changes made to the store are discarded.
  def rollback
    root.load_from_store
    finish_transaction
  end
  
  # Finish the transaction.
  #
  # Release the lock file.
  def finish_transaction
    Thread.current['git_store_lock'].close rescue nil
    Thread.current['git_store_lock'] = nil
    
    File.unlink("#{head_path}.lock") rescue nil    
  end

  # Write the commit object to disk and set the head of the current branch.
  #
  # Returns the id of the commit object
  def commit(message = '', author = 'ruby', committer = 'ruby')
    time = "#{ Time.now.to_i } #{ Time.now.to_s.split[4] }"
    tree = root.write_to_store

    contents = [ "tree #{tree}", (head and "parent #{head}"),
                 "author #{author} #{time}",
                 "committer #{committer} #{time}", '', message
                 ].compact.join("\n")

    id = put_object(contents, 'commit')

    open(head_path, "wb") do |file|
      file.write(id)
    end

    @head = id
  end

  # Read the raw object with the given id from the repository.
  #
  # Returns a pair of content and type of the object
  def get_object(id)
    path = object_path(id)
    
    if File.exists?(path)
      buf = open(path, "rb") { |f| f.read }
    else
      get_object_from_pack(id)
    end
    
    raise if not legacy_loose_object?(buf)
    
    header, content = Zlib::Inflate.inflate(buf).split(/\0/, 2)
    type, size = header.split(/ /, 2)
    
    raise if size.to_i != content.size
    
    return content, type
  end

  def get_object_from_pack(id)
    packs.each do |pack|
      data = pack[id] and return data
    end
  end      

  # Returns the hash value of an object string.
  def sha(str)
    Digest::SHA1.hexdigest(str)[0, 40]
  end

  # Write a raw object to the repository.
  #
  # Returns the object id.
  def put_object(content, type)
    size = content.length.to_s    
    header = "#{type} #{size}\0"
    data = header + content
    
    id = sha(data)
    path = object_path(id)
    
    unless File.exists?(path)
      FileUtils.mkpath(File.dirname(path))
      open(path, 'wb') do |f|
        f.write Zlib::Deflate.deflate(data)
      end
    end
    
    id
  end

  def legacy_loose_object?(buf)
    word = (buf[0] << 8) + buf[1]
    buf[0] == 0x78 && word % 31 == 0
  end  

  def load_packs(path)
    if File.directory?(path)
      Dir.open(path) do |dir|
        entries = dir.select { |entry| entry =~ /\.pack$/i }
        @packs = entries.map { |entry| PackStorage.new(File.join(path, entry)) }
      end
    end
  end
  
  # FileStore reads a working copy out of a directory. Changes made to
  # the store will not be written to a repository. This is useful, if
  # you want to read a filesystem without having a git repository.
  class FileStore < GitStore

    def initialize(path)
      @mtime = {}
      super
    end

    def load
      root.load_from_disk
      
      each_blob_in(root) do |blob|
        @mtime[blob.path] = File.mtime("#{path}/#{blob.path}")
      end
    end

    def each_blob_in(tree, &blob)
      tree.table.each do |name, entry|
        case entry
        when Blob; yield entry
        when Tree; each_blob_in(entry, &blob)
        end
      end
    end        

    def refresh!
      each_blob_in(root) do |blob|
        path = "#{self.path}/#{blob.path}"
        if File.exist?(path)
          mtime = File.mtime(path)
          if @mtime[blob.path] != mtime
            @mtime[blob.path] = mtime
            blob.load_from_disk
          end
        else
          delete blob.path
        end
      end
    end

    def commit(message="")
    end
    
  end

end

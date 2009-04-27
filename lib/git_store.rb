require 'rubygems'
require 'zlib'
require 'digest/sha1'
require 'yaml'
require 'fileutils'

require 'git_store/blob'
require 'git_store/tree'
require 'git_store/pack'
require 'git_store/commit'
require 'git_store/handlers'

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

  TYPE_CLASS = {
    'tree' => Tree,
    'blob' => Blob,
    'commit' => Commit
  }     

  attr_reader :path, :index, :root, :branch, :lock_file, :head, :packs, :handler

  # Initialize a store.
  def initialize(path, branch = 'master')
    @path    = path.chomp('/')
    @branch  = branch
    @root    = Tree.new(self)
    @packs   = {}
    @handler = {
      'yml' => YAMLHandler.new
    }
    
    @handler.default = DefaultHandler.new      
    
    raise(ArgumentError, "first argument must be a valid Git repository: `#{path}'") unless valid?

    load_packs("#{path}/.git/objects/pack")
    load
  end

  def valid?
    File.exists?("#{path}/.git")
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
  def read_head_id
    File.read(head_path).strip if File.exists?(head_path)
  end

  def handler_for(path)
    handler[ path.split('.').last ]
  end

  # Read an object for the specified path.
  def [](path)
    root[path] 
  end

  # Write an object to the specified path.
  def []=(path, data)
    root[path] = data
  end

  # Iterate over all key-values pairs found in this store.
  def each(&block)
    root.each(&block)
  end

  def paths
    root.paths
  end

  def values
    root.values
  end

  def delete(path)
    root.delete(path)
  end

  # Returns the store as a hash tree.
  def to_hash
    root.to_hash
  end

  # Inspect the store.
  def inspect
    "#<GitStore #{path} #{branch} #{root.to_hash.inspect}>"
  end

  # Has our store been changed on disk?
  def changed?
    head.nil? or head.id != read_head_id
  end

  # Load the current head version from repository. 
  def load
    if id = read_head_id
      @head = get(id)
      @root = get(@head.tree)
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
    load
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

    commit = Commit.new(self)
    commit.tree = root.write_to_store
    commit.parent << head if head
    commit.author = "#{author} #{time}"
    commit.committer = "#{committer} #{time}"
    commit.message = message

    id = commit.write_to_store

    open(head_path, "wb") do |file|
      file.write(id)
    end

    @head = commit
  end

  def log
    
  end

  # Read the raw object with the given id from the repository.
  #
  # Returns a pair of content and type of the object
  def get_object(id)
    path = object_path(id)
    
    if File.exists?(path)
      buf = open(path, "rb") { |f| f.read }

      raise if not legacy_loose_object?(buf)
      
      header, content = Zlib::Inflate.inflate(buf).split(/\0/, 2)
      type, size = header.split(/ /, 2)
    else
      content, type = get_object_from_pack(id)
    end
    
    return content, type
  end

  def get(id)
    content, type = get_object(id)

    klass = TYPE_CLASS[type]
    klass.new(self, id, content)
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

  def get_object_from_pack(id)
    pack, offset = @packs[id]
    
    pack.parse_object(offset) if pack
  end      

  def load_packs(path)
    if File.directory?(path)
      Dir.open(path) do |dir|        
        entries = dir.select { |entry| entry =~ /\.pack$/i }
        entries.each do |entry|
          pack = PackStorage.new(File.join(path, entry))
          pack.each_entry do |id, offset|
            id = id.unpack("H*").first
            @packs[id] = [pack, offset]
          end
        end
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
    rescue ArgumentError
    end

    def load
      root.load_from_disk('')

      each do |path, data|
        file = "#{self.path}/#{path}"
        
        if File.exist?(file)
          mtime = File.mtime(file)
          
          if @mtime[path] != mtime
            @mtime[path] = mtime
            blob = root.resolv(path)
            blob.load_from_disk(path)
          end
        end
      end
    end

    def commit(message="")
    end
    
  end

end

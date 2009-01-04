require 'rubygems'
require 'grit'
require 'yaml'

require 'git_store/blob'
require 'git_store/tree'
require 'git_store/handlers'

class GitStore
  include Enumerable

  attr_reader :repo, :index, :root, :last_commit

  def initialize(path = '.')
    @repo = Grit::Repo.new(path)
    @root = Tree.new('')
    load_last_commit
  end

  def load_last_commit
    @last_commit = @repo.commits('master', 1)[0]
  end
  
  def commit(message="")
    head = repo.heads.first
    commit_index(message, head ? head.commit.id : nil)
  end
  
  def [](*args)
    root[*args]
  end

  def []=(*args)
    value = args.pop
    root[*args] = value
  end

  def delete(path)
    root.delete(path)
  end

  def load
    root.load(repo.tree)
  end

  def each(&block)
    root.each(&block)
  end

  def changed?
    commit = repo.commits('master', 1)[0]
    commit and (last_commit.nil? or last_commit.id != commit.id)
  end

  def refresh!
    load if changed?
  end

  def start_transaction(head = 'master')
    @lock = open("#{repo.path}/refs/heads/#{head}.lock", "w")
    @lock.flock(File::LOCK_EX)
  end

  def commit_index(message, parents = nil, actor = nil, head = 'master')
    start_transaction(head) unless @lock
    
    tree_sha = write_tree(root)
    
    contents = []
    contents << ['tree', tree_sha].join(' ')

    if parents
      parents.each do |p|
        contents << ['parent', p].join(' ') if p        
      end
    end

    if actor
      name = actor.name
      email = actor.email
    else
      config = Grit::Config.new(self.repo)
      name = config['user.name']
      email = config['user.email']
    end
    
    author_string = "#{name} <#{email}> #{Time.now.to_i} -0700"
    contents << ['author', author_string].join(' ')
    contents << ['committer', author_string].join(' ')
    contents << ''
    contents << message
    
    commit_sha = put_raw_object(contents.join("\n"), 'commit')
    
    open("#{repo.path}/refs/heads/#{head}", "w") do |file|
      file.write(commit_sha)
    end
    
    commit_sha
  ensure
    @lock.close if @lock
    @lock = nil
    File.unlink("#{repo.path}/refs/heads/#{head}.lock") rescue nil
  end

  def put_raw_object(data, type)
    repo.git.ruby_git.put_raw_object(data, type)
  end

  def write_blob(blob)
    return if not blob.modified?
    
    blob.sha1 = put_raw_object(blob.serialize, 'blob')
    blob.modified = false
  end
  
  def write_tree(tree)
    return if not tree.modified?
    
    contents = tree.data.map do |name, entry|
      case entry
      when Blob; write_blob(entry)
      when Tree; write_tree(entry)
      end
      "%s %s\0%s" % [entry.mode, name, [entry.sha1].pack("H*")]
    end

    tree.modified = false
    tree.sha1 = put_raw_object(contents.join, 'tree')
  end
  
  class FileStore < GitStore

    attr_reader :path
    
    def initialize(path = '.')
      @path = path
      @root = Tree.new('')
    end

    def load
      root.load_from_disk
    end

    def refresh!
      root.each_blob do |blob|
        
      end
    end

    def commit(message="")
      root.write_to_disk
    end
    
  end

end

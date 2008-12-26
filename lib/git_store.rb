require 'grit'

# This fix ensures sorted yaml maps.
class Hash
	def to_yaml( opts = {} )
		YAML::quick_emit( object_id, opts ) do |out|
      out.map( taguri, to_yaml_style ) do |map|
        sort_by { |k, v| k.to_s }.each do |k, v|
          map.add( k, v )
        end
      end
    end
	end
end

class GitStore

  class DefaultHandler
    def read(name, data)
      data
    end

    def write(data)
      data
    end
  end
  
  class YAMLHandler    
    def read(name, data)
      YAML.load(data)
    end

    def write(data)
      data.to_yaml
    end    
  end

  class RubyHandler
    def read(name, data)
      Object.module_eval(data)
    end
  end

  class ERBHandler
    def read(name, data)
      ERB.new(data)
    end
  end

  Handler = {
    'yml' => YAMLHandler.new,
    'rhtml' => ERBHandler.new,
    'rxml' => ERBHandler.new,
    'rb' => RubyHandler.new
  }

  Handler.default = DefaultHandler.new

  class Blob

    attr_reader :id
    attr_accessor :name

    def initialize(*args)
      if args.first.is_a?(Grit::Blob)
        @blob = args.first
        @name = @blob.name
      else
        @name = args[0]
        self.data = args[1]
      end
    end

    def extname
      File.extname(name)[1..-1]
    end

    def load(data)
      @data = handler.read(name, data)
    end

    def handler
      Handler[extname]
    end

    def data
      @data or (@blob and load(@blob.data))
    end

    def data=(data)
      @data = data
    end

    def to_s
      if handler.respond_to?(:write)
        handler.write(data)
      else
        @blob.data
      end
    end
    
  end

  class Tree
    include Enumerable

    attr_reader :data
    attr_accessor :name
    
    def initialize(name = nil)
      @data = {}
      @name = name
    end

    def load(tree)
      @name = tree.name
      @data = tree.contents.inject({}) do |hash, file|
        if file.is_a?(Grit::Tree)
          hash[file.name] = (@data[file.name] || Tree.new).load(file)
        else          
          hash[file.name] = Blob.new(file)
        end
        hash
      end
      self
    end

    def inspect
      "#<GitStore::Tree #{@data.inspect}>"
    end

    def fetch(name)
      name = name.to_s
      entry = @data[name]
      case entry
      when Blob then entry.data
      when Tree then entry
      end      
    end

    def store(name, value)
      name = name.to_s
      if value.is_a?(Tree)
        value.name = name
        @data[name] = value
      else
        @data[name] = Blob.new(name, value)
      end
    end

    def has_key?(name)
      @data.has_key?(name)
    end

    def [](*args)
      args = args.first.to_s.split('/') if args.size == 1
      args.inject(self) { |tree, key| tree.fetch(key) or return nil }
    end

    def []=(*args)
      value = args.pop
      args = args.first.to_s.split('/') if args.size == 1
      tree = args[0..-2].to_a.inject(self) do |tree, key|
        tree.has_key?(key) ? tree.fetch(key) : tree.store(key, Tree.new(key))
      end
      tree.store(args.last, value)
    end

    def delete(name)
      @data.delete(name)
    end
    
    def each(&block)
      @data.values.each do |entry|
        case entry
        when Blob then yield entry.data
        when Tree then entry.each(&block)
        end
      end
    end

    def each_with_path(path = [], &block)
      @data.each do |name, entry|
        child_path = path + [name]
        case entry
        when Blob then yield entry, child_path.join('/')
        when Tree then entry.each_with_path(child_path, &block)
        end        
      end
    end
      
    def to_hash
      @data.inject({}) do |hash, (name, entry)|
        hash[name] = entry.is_a?(Tree) ? entry.to_hash : entry.to_s
        hash
      end
    end
    
  end

  attr_reader :repo, :index, :tree

  def initialize(path, &block)
    @repo = Grit::Repo.new(path)
    @index = Grit::Index.new(@repo)
    @tree = Tree.new
  end

  def commit(message="")
    index.tree = tree.to_hash
    head = repo.heads.first
    index.commit(message, head ? head.commit.id : nil)
  end

  def [](*args)
    tree[*args]
  end

  def []=(*args)
    value = args.pop
    tree[*args] = value
  end

  def delete(path)
    tree.delete(path)
  end

  def load
    tree.load(repo.tree)
  end

  def each(&block)
    tree.each(&block)
  end

  def each_with_path(&block)
    tree.each_with_path(&block)
  end

end

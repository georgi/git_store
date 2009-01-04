class GitStore

  class Tree
    include Enumerable

    attr_reader :data
    attr_accessor :path, :sha1, :mode, :modified
    
    def initialize(path = nil, modified = false)
      @data = {}
      @path = path
      @mode = '040000'
      @modified = modified
    end

    def name
      File.basename(path)
    end

    def modified?
      @modified || @data.values.any? { |child| child.modified? }
    end

    def write_to_disk
      @data.each do |name, entry|
        entry.write_to_disk
      end
    end

    def load_from_disk(path = '')
      @path = path
      @mode = '%o' % File.stat("./#{path}").mode

      pattern = path.empty? ? "./*" : "./#{path}/*"
      
      @data = Dir[pattern].inject({}) do |hash, file|
        file = file[2..-1]
        if file[-1, 1] != '~'
          name = File.basename(file)
          if File.directory?(file)
            hash[name] = (@data[name] || Tree.new).load_from_disk(file)
          else
            hash[name] = Blob.new(File.open(file), file)
          end
        end
        hash
      end
      
      self
    end

    def load(tree, path = '')
      @path = path
      @mode = tree.mode
      
      @data = tree.contents.inject({}) do |hash, file|
        name = file.name
        if file.is_a?(Grit::Tree)
          hash[name] = (@data[name] || Tree.new).load(file, child_path(name))
        else
          hash[name] = Blob.new(file, child_path(name))
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
      when Blob; entry.data
      when Tree; entry
      end
    end

    def child_path(name)
      path.empty? ? name : "#{path}/#{name}"
    end

    def create_tree(name)
      store(name, Tree.new(child_path(name)))
    end

    def store(name, value)
      @modified = true
      name = name.to_s
      
      if value.is_a?(Tree)
        value.path = child_path(name)
        @data[name] = value
      else
        @data[name] = Blob.new(value, child_path(name), true)
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
        tree.has_key?(key) ? tree.fetch(key) : tree.create_tree(key)
      end
      tree.store(args.last, value)
    end

    def delete(name)
      @data.delete(name)
    end

    def each(&block)
      @data.sort.each do |name, entry|
        case entry
        when Blob; yield entry.data
        when Tree; entry.each(&block)
        end
      end
    end

    def each_blob(&block)
      @data.sort.each do |name, entry|
        case entry
        when Blob; yield entry
        when Tree; entry.each_blob(&block)
        end
      end
    end

    def to_hash
      @data.inject({}) do |hash, (name, entry)|
        hash[name] = entry.is_a?(Tree) ? entry.to_hash : entry.serialize
        hash
      end
    end
    
  end

end

require 'strscan'

class GitStore

  class Tree
    TYPE_CLASS = {
      'tree' => Tree,
      'blob' => Blob
    }
    
    include Enumerable

    attr_reader :store
    attr_accessor :id, :mode, :path, :data, :table

    # Initialize a tree with default mode '040000'
    def initialize(store)
      @store = store      
      @mode ||= '040000'
      @path = ''
      @table = {}
    end

    # Set all attributes at once.
    def set(id, mode = '040000', path = nil, data = nil)
      @id, @mode, @path, @data = id, mode, path, data
    end

    # Does this tree exist in the repository?
    def created?
      not @id.nil?
    end

    # Has this tree been modified?
    def modified?
      @modified || (table && table.values.any? { |value| value.modified? })
    end

    # Path of a child element with specified name.
    def child_path(name)
      path.empty? ? name : "#{path}/#{name}"
    end

    # Find or create a subtree with specified name.
    def tree(name)
      get(name) or put(name, Tree.new(store))
    end

    # Load this tree from a real directory instead of a repository.
    def load_from_disk
      dir = File.join(store.path, self.path)
      entries = Dir.entries(dir) - ['.', '..']
      @table = entries.inject({}) do |hash, name|
        if name[-1, 1] != '~' && name[0, 1] != '.'
          path = "#{dir}/#{name}"
          stat = File.stat(path)
          mode = '%o' % stat.mode
          klass = stat.directory? ? Tree : Blob
          
          child = table[name] ||= klass.new(store)
          child.set(nil, mode, child_path(name), data)
          child.load_from_disk
          
          hash[name] = child
        end        
        hash
      end
    end

    # Read the contents of a raw git object.
    #
    # Return an array of [mode, name, id] entries.
    def read_contents(data)
      scanner = StringScanner.new(data)
      contents = []
      
      while scanner.scan(/(.*?) (.*?)\0(.{20})/m)
        contents << [scanner[1], scanner[2], scanner[3].unpack("H*").first]
      end

      contents
    end

    # Load this tree from a git repository.
    def load_from_store
      @table = read_contents(data).inject({}) do |hash, (mode, name, id)|
        content, type = store.get_object(id)

        child = table[name] || TYPE_CLASS[type].new(store)
        child.set(id, mode, child_path(name), content)
        child.load_from_store if Tree === child

        hash[name] = child
        hash
      end
    end

    # Write this tree back to the git repository.
    #
    # Returns the object id of the tree.
    def write_to_store
      return id if not modified?
      
      contents = table.map do |name, entry|
        entry.write_to_store
        "%s %s\0%s" % [entry.mode, name, [entry.id].pack("H*")]
      end

      @modified = false
      @id = store.put_object(contents.join, 'tree')
    end
    
    # Read entry with specified name.
    def get(name)
      name = name.to_s
      entry = table[name]
      
      case entry
      when Blob; entry.object
      when Tree; entry
      end
    end

    # Write entry with specified name.
    def put(name, value)
      @modified = true
      name = name.to_s
      
      if value.is_a?(Tree)
        value.path = child_path(name)
        table[name] = value
      else
        blob = table[name]
        blob = Blob.new(store) if not blob.is_a?(Blob)
        blob.path = child_path(name)
        blob.object = value
        table[name] = blob          
      end

      value
    end

    # Remove entry with specified name.
    def remove(name)
      @modified = true
      table.delete(name.to_s)
    end

    # Does this key exist in the table?
    def has_key?(name)
      table.has_key?(name)
    end

    # Read a value on specified path.
    #
    # Use an argument list or a string with slashes.
    def [](*args)
      args = args.first.to_s.split('/') if args.size == 1
      args.inject(self) { |tree, key| tree.get(key) or return nil }
    end

    # Write a value on specified path.
    #
    # Use an argument list or a string with slashes.
    def []=(*args)
      value = args.pop
      args = args.first.to_s.split('/') if args.size == 1
      tree = args[0..-2].to_a.inject(self) { |tree, name| tree.tree(name) }
      tree.put(args.last, value)
    end

    # Delete a value on specified path.
    #
    # Use an argument list or a string with slashes.
    def delete(*args)
      args = args.first.to_s.split('/') if args.size == 1
      tree = args[0..-2].to_a.inject(self) do |tree, key|
        tree.get(key) or return
      end
      tree.remove(args.last)
    end

    # Iterate over all objects found in this subtree.
    def each(&block)
      table.sort.each do |name, entry|
        case entry
        when Blob; yield entry.object
        when Tree; entry.each(&block)
        end
      end
    end

    # Convert this tree into a hash object.
    def to_hash
      table.inject({}) do |hash, (name, entry)|
        hash[name] = entry.is_a?(Tree) ? entry.to_hash : entry.object
        hash
      end
    end

    def inspect
      "#<GitStore::Tree #{id} #{mode} #{to_hash.inspect}>"
    end
    
  end

end

class GitStore

  class Tree
    include Enumerable

    attr_reader :store
    attr_accessor :id, :data, :table

    # Initialize a tree
    def initialize(store, id = nil, data = nil)
      @store = store
      @id = id
      @data = data
      @table = {}
      load_from_store if data
    end

    # Does this tree exist in the repository?
    def created?
      not @id.nil?
    end

    # Has this tree been modified?
    def modified?
      @modified || (table && table.values.any? { |value| value.modified? })
    end

    # Find or create a subtree with specified name.
    def tree(name)
      get(name) or put(name, Tree.new(store))
    end

    # Load this tree from a real directory.
    def load_from_disk(path)
      dir = File.join(store.path, path)
      entries = Dir.entries(dir)

      @table.clear

      entries.each do |name|
        if name[-1, 1] != '~' && name[0, 1] != '.'
          stat = File.stat("#{dir}/#{name}")
          klass = stat.directory? ? Tree : Blob
          child = klass.new(store)
          child.load_from_disk("#{path}/#{name}")
          @table[name] = child
        end        
      end
    end

    # Read the contents of a raw git object.
    #
    # Return an array of [name, id] entries.
    def read_contents(data)
      contents = []

      while data.size > 0
        mode, data = data.split(" ", 2)
        name, data = data.split("\0", 2)
        id = data.slice!(0, 20).unpack("H*").first
        contents << [ name, id ]
      end

      contents
    end

    # Load this tree from a git repository.
    def load_from_store
      @table.clear
      read_contents(data).each do |name, id|
        @table[name] = store.get(id)
      end
    end

    # Write this tree back to the git repository.
    #
    # Returns the object id of the tree.
    def write_to_store
      return id if not modified?
      
      contents = table.map do |name, entry|
        entry.write_to_store
        "0777 %s\0%s" % [name, [entry.id].pack("H*")]
      end

      @modified = false
      @id = store.put_object(contents.join, 'tree')
    end

    def handler_for(name)
      store.handler_for(name)
    end

    # Read entry with specified name.
    def get(name)
      entry = table[name]
      
      case entry
      when Blob; handler_for(name).read(entry.data)
      when Tree; entry
      end
    end

    # Write entry with specified name.
    def put(name, value)
      @modified = true
      
      if value.is_a?(Tree)
        table[name] = value
      else
        table[name] = Blob.new(store, nil, handler_for(name).write(value))
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
      table.has_key?(name.to_s)
    end

    def normalize_path(path)
      path[0, 1] == '/' ? path[1..-1] : path
    end    

    # Read a value on specified path.
    def [](path)
      normalize_path(path).split('/').inject(self) { |tree, key| tree.get(key) or return nil }
    end

    def resolv(path)
      normalize_path(path).split('/').inject(self) { |tree, key| tree.table[key] or return nil }
    end

    # Write a value on specified path.
    def []=(path, value)
      list = normalize_path(path).split('/')
      tree = list[0..-2].to_a.inject(self) { |tree, name| tree.tree(name) }
      tree.put(list.last, value)
    end

    # Delete a value on specified path.
    def delete(path)
      list = normalize_path(path).split('/')
      
      tree = list[0..-2].to_a.inject(self) do |tree, key|
        tree.get(key) or return
      end
      
      tree.remove(list.last)
    end

    # Iterate over all objects found in this subtree.
    def each(path = [], &block)
      table.sort.each do |name, entry|
        child_path = path + [name]
        case entry
        when Blob
          yield child_path.join("/"), handler_for(name).read(entry.data)
          
        when Tree
          entry.each(child_path, &block)
        end
      end
    end
    
    def paths
      map { |path, data| path }
    end

    def values
      map { |path, data| data }
    end

    # Convert this tree into a hash object.
    def to_hash
      table.inject({}) do |hash, (name, entry)|
        hash[name] = entry.is_a?(Tree) ? entry.to_hash : handler_for(name).read(entry.data)
        hash
      end
    end

    def inspect
      "#<GitStore::Tree #{id} #{mode} #{to_hash.inspect}>"
    end
    
  end

end

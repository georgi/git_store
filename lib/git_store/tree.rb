class GitStore

  class Tree
    include Enumerable

    attr_reader :store, :table
    attr_accessor :id, :data, :mode

    # Initialize a tree
    def initialize(store, id = nil, data = nil)
      @store = store
      @id = id
      @table = {}
      @mode = "040000"
      parse(data) if data
    end

    def ==(other)
      Tree === other and id == other.id
    end

    # Has this tree been modified?
    def modified?
      @modified or @table.values.any? { |entry| Tree === entry and entry.modified? }
    end

    # Find or create a subtree with specified name.
    def tree(name)
      get(name) or put(name, Tree.new(store))
    end

    # Read the contents of a raw git object.
    def parse(data)
      @table.clear

      while data.size > 0
        mode, data = data.split(" ", 2)
        name, data = data.split("\0", 2)
        id = data.slice!(0, 20).unpack("H*").first
        
        @table[name] = store.get(id)
      end
    end

    def dump
      @table.map { |k, v| "#{ v.mode } #{ k }\0#{ [v.write].pack("H*") }" }.join
    end
    
    # Write this tree back to the git repository.
    #
    # Returns the object id of the tree.
    def write
      return id if not modified?      
      @modified = false
      @id = store.put(self)
    end

    # Read entry with specified name.
    def get(name)
      entry = @table[name]
      
      case entry
      when Blob
        entry.object ||= handler_for(name).read(entry.data)
          
      when Tree
        entry
      end
    end

    def handler_for(name)
      store.handler_for(name)
    end    

    # Write entry with specified name.
    def put(name, value)
      @modified = true
      
      if value.is_a?(Tree)
        @table[name] = value
      else
        @table[name] = Blob.new(store, nil, handler_for(name).write(value))
      end
     
      value
    end

    # Remove entry with specified name.
    def remove(name)
      @modified = true
      @table.delete(name.to_s)
    end

    # Does this key exist in the table?
    def has_key?(name)
      @table.has_key?(name.to_s)
    end

    def normalize_path(path)
      (path[0, 1] == '/' ? path[1..-1] : path).split('/')
    end    

    # Read a value on specified path.
    def [](path)
      normalize_path(path).inject(self) do |tree, key|
        tree.get(key) or return nil
      end
    end

    # Write a value on specified path.
    def []=(path, value)
      list = normalize_path(path)
      tree = list[0..-2].to_a.inject(self) { |tree, name| tree.tree(name) }
      tree.put(list.last, value)
    end

    # Delete a value on specified path.
    def delete(path)
      list = normalize_path(path)
      
      tree = list[0..-2].to_a.inject(self) do |tree, key|
        tree.get(key) or return
      end
      
      tree.remove(list.last)
    end

    # Iterate over all objects found in this subtree.
    def each(path = [], &block)
      @table.sort.each do |name, entry|
        child_path = path + [name]
        case entry
        when Blob
          entry.object ||= handler_for(name).read(entry.data)
          yield child_path.join("/"), entry.object
          
        when Tree
          entry.each(child_path, &block)
        end
      end
    end

    def each_blob(path = [], &block)
      @table.sort.each do |name, entry|
        child_path = path + [name]

        case entry
        when Blob
          yield child_path.join("/"), entry
          
        when Tree
          entry.each_blob(child_path, &block)
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
      @table.inject({}) do |hash, (name, entry)|
        if entry.is_a?(Tree) 
          hash[name] = entry.to_hash
        else
          hash[name] = entry.object ||= handler_for(name).read(entry.data)
        end
        hash
      end
    end

    def inspect
      "#<GitStore::Tree #{id} #{mode} #{to_hash.inspect}>"
    end
    
  end

end

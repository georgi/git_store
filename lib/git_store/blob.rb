class GitStore

  # This class stores the raw string data of a blob, but also the
  # deserialized data object.
  class Blob

    attr_accessor :store, :id, :mode, :path, :data

    # Initialize a Blob with default mode of '100644'.
    def initialize(store)
      @store = store
      @mode = '100644'
    end

    # Set all attributes at once.
    def set(id, mode = nil, path = nil, data = nil, object = nil)
      @id, @mode, @path, @data, @object = id, mode, path, data, object
    end

    # Returns the extension of the filename.
    def extname
      File.extname(path)[1..-1]
    end

    # Returns the handler for serializing the blob data.
    def handler
      Handler[extname]
    end

    # Returns true if data is new or hash value is different from current id.
    def modified?
      id.nil? || @modified
    end

    # Returns the data object.
    def object
      @object ||= handler.read(path, data)
    end

    # Set the data object.
    def object=(value)
      @modified = true
      @object = value
      @data = handler.respond_to?(:write) ? handler.write(path, value) : value
    end

    def load_from_disk
      @object = nil
      @data = open("#{store.path}/#{path}", 'rb') { |f| f.read }
    end

    # Write the data to the git object store
    def write_to_store      
      if modified?
        @modified = false
        @id = store.put_object(data, 'blob')
      else
        @id
      end
    end   

  end

end

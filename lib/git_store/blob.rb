class GitStore

  # This class stores the raw string data of a blob, but also the
  # deserialized data object.
  class Blob

    attr_accessor :store, :id, :data

    # Initialize a Blob
    def initialize(store, id = nil, data = nil)
      @store = store
      @id = id
      @data = data
    end

    # Returns true if id is nil.
    def modified?
      id.nil?
    end

    def load_from_store
    end
    
    def load_from_disk(path)
      @data = open("#{store.path}/#{path}", 'rb') { |f| f.read }
    end

    # Write the data to the git object store
    def write_to_store      
      return @id if @id      
      @id = store.put_object(data, 'blob')
    end   

  end

end

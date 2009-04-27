class GitStore

  # This class stores the raw string data of a blob, but also the
  # deserialized data object.
  class Blob

    attr_accessor :store, :id, :data, :mode, :object

    # Initialize a Blob
    def initialize(store, id = nil, data = nil)
      @store = store
      @id = id
      @data = data
      @mode = "100644"
    end

    # Returns true if id is nil.
    def modified?
      id.nil?
    end

    # Write the data to the git object store
    def write
      return @id if @id      
      @id = store.put_object('blob', data)
    end   

  end

end

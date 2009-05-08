class GitStore

  # This class stores the raw string data of a blob, but also the
  # deserialized data object.
  class Blob

    attr_accessor :store, :id, :data, :mode, :object

    # Initialize a Blob
    def initialize(store, id = nil, data = nil)
      @store = store
      @id = id || store.id_for('blob', data)
      @data = data
      @mode = "100644"
    end

    def ==(other)
      Blob === other and id == other.id
    end

    def dump
      @data
    end

    # Write the data to the git object store
    def write
      @id = store.put(self)
    end

  end

end

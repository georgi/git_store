class GitStore

  class Commit 
    attr_accessor :store, :id, :data, :author, :committer, :tree, :parent, :message, :headers

    def initialize(store, id = nil, data = nil)
      @store = store
      @id = data
      @data = data
      @parent = []

      parse_data if data
    end

    def parse_data
      @headers, @message = data.split(/\n\n/, 2)
      
      @headers.split(/\n/).each do |header|
        key, value = header.split(/ /, 2)
        
        if key == 'parent'
          @parent << value
        else
          instance_variable_set "@#{key}", value
        end
      end

      self
    end

    def write_to_store
      store.put_object(to_s, 'commit')
    end

    def to_s
      [ "tree #@tree",
        @parent.map { |parent| "parent #{parent}" },
        "author #@author",
        "committer #@committer",
        '',
        @message ].flatten.join("\n")
    end
    
  end

end

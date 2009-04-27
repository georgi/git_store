class GitStore

  class Commit 
    attr_accessor :store, :id, :data, :author, :committer, :tree, :parent, :message, :headers

    def initialize(store, id = nil, data = nil)
      @store = store
      @id = id
      @parent = []

      parse(data) if data
    end

    def parse(data)
      headers, @message = data.split(/\n\n/, 2)

      headers.split(/\n/).each do |header|
        key, value = header.split(/ /, 2)
        if key == 'parent'
          @parent << value
        else
          instance_variable_set "@#{key}", value
        end
      end

      self
    end

    def write
      @id = store.put_object('commit', dump)
    end

    def dump
      [ "tree #@tree",
        @parent.map { |parent| "parent #{parent}" },
        "author #@author",
        "committer #@committer",
        '',
        @message ].flatten.join("\n")
    end
    
  end

end

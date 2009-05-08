class GitStore

  class Tag
    attr_accessor :store, :id, :object, :type, :tagger, :message

    def initialize(store, id = nil, data = nil)
      @store = store
      @id = id

      parse(data) if data
    end

    def ==(other)
      Tag === other and id == other.id
    end        

    def parse(data)
      headers, @message = data.split(/\n\n/, 2)

      headers.split(/\n/).each do |header|
        key, value = header.split(/ /, 2)
        case key
        when 'type'
          @type = value

        when 'object'
          @object = store.get(value)

        when 'tagger'
          @tagger = User.parse(value)

        end
      end

      self
    end

  end

end

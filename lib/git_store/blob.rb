class GitStore

  class Blob

    attr_accessor :sha1, :mode, :path, :blob, :file, :modified
    alias_method :modified?, :modified

    def initialize(data, path, modified = false)
      @path = path
      @modified = modified
      
      case data
      when Grit::Blob
        @blob = data
        @sha1 = blob.id
        @mode = blob.mode
      when File
        @file = data
        @sha1 = Digest::SHA1.hexdigest(file.read)
        @mode = '%o' % file.stat.mode
      else
        @data = data
        @sha1 = Digest::SHA1.hexdigest(serialize)
        @mode = '100644'
      end
    end

    def name
      File.basename(path)
    end

    def extname
      File.extname(name)[1..-1]
    end

    def load(data)
      handler.read(path, data)
    end

    def reload
      load raw_data
    end

    def raw_data
      if @blob
        @blob.data
      elsif @file
        @file.rewind
        @file.read
      end
    end

    def handler
      Handler[extname]
    end

    def data
      @data ||= load(raw_data)
    end

    def data=(data)
      @data = data
    end

    def write_to_disk
      if handler.respond_to?(:write)
        FileUtils.mkpath(File.dirname(path))
        open(path, "w") do |io|
          io << handler.write(path, data)
        end
      end
    end

    def serialize
      if handler.respond_to?(:write)
        handler.write(path, data)
      else
        raw_data
      end
    end
    
  end

end

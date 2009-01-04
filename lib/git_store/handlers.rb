
# This fix ensures sorted yaml maps.
class Hash
	def to_yaml( opts = {} )
		YAML::quick_emit( object_id, opts ) do |out|
      out.map( taguri, to_yaml_style ) do |map|
        sort_by { |k, v| k.to_s }.each do |k, v|
          map.add( k, v )
        end
      end
    end
	end
end

class GitStore

  class DefaultHandler
    def read(path, data)
      data
    end
    
    def write(path, data)
      data.to_s
    end
  end
  
  class YAMLHandler    
    def read(path, data)
      YAML.load(data)
    end

    def write(path, data)
      data.to_yaml
    end    
  end

  class RubyHandler
    def read(path, data)
      Object.module_eval(data)
    end
  end

  class ERBHandler
    def read(path, data)
      ERB.new(data)
    end
  end

  Handler = {
    'yml' => YAMLHandler.new,
    'rhtml' => ERBHandler.new,
    'rxml' => ERBHandler.new,
    'rb' => RubyHandler.new
  }

  Handler.default = DefaultHandler.new
end

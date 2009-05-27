
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
    def read(data)
      data
    end

    def write(data)
      data.to_s
    end
  end

  class YAMLHandler
    def read(data)
      YAML.load(data)
    end

    def write(data)
      data.to_yaml
    end
  end
end

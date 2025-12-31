require 'date'

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
      YAML.safe_load(data, permitted_classes: [Symbol, Date, Time])
    end

    def write(data)
      data.to_yaml
    end
  end
end

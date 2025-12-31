class GitStore
  class User < Struct.new(:name, :email, :time)
    def dump
      "#{ name } <#{email}> #{ time.to_i } #{ time.strftime('%z') }"
    end
    alias to_s dump

    def inspect
      "#<GitStore::User name=%p email=%p time=%p>" % [name, email, time]
    end

    def self.from_config
      name, email = config_get('user.name'), config_get('user.email')
      new name, email, Time.now
    end

    def self.config_get(key)
      value = `git config #{key}`.chomp

      if $?.exitstatus == 0
        return value unless value.empty?
        raise RuntimeError, "#{key} is empty"
      else
        raise RuntimeError, "No #{key} found in git config"
      end
    end

    def self.config_user_email
      email = `git config user.email`.chomp
    end

    def self.parse(user)
      if match = user.match(/(.*)<(.*)> (\d+) ([+-]\d+)/)
        new match[1].strip, match[2].strip, Time.at(match[3].to_i + match[4].to_i * 3600)
      end
    end
  end
end

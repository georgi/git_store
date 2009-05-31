class GitStore
  class User < Struct.new(:name, :email, :time)
    def dump
      "#{ name } <#{email}> #{ time.to_i } #{ time.strftime('%z') }"
    end
    alias to_s dump

    def inspect
      "#<GitStore::User name=%p email=%p time=%p>" % [name, email, time]
    end

      new name, email, Time.now
    end

    def self.parse(user)
      if match = user.match(/(.*)<(.*)> (\d+) ([+-]\d+)/)
        new match[1].strip, match[2].strip, Time.at(match[3].to_i + match[4].to_i * 3600)
      end
    end

  end

end

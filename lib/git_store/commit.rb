class GitStore

  class Commit 
    attr_accessor :store, :id, :data, :author, :committer, :tree, :parent, :message, :headers
    attr_reader :author_name, :author_email, :author_time
    attr_reader :committer_name, :committer_email, :committer_time

    def initialize(store, id = nil, data = nil)
      @store = store
      @id = id
      @parent = []

      parse(data) if data

      @author_name, @author_email, @author_time = parse_user(author) if author
      @committer_name, @commiter_email, @committer_time = parse_user(committer) if committer
    end

    def parse_user(user)
      if match = user.match(/(.*)<(.*)> (\d+) ([+-]\d+)/)
        [ match[1].chomp,
          match[2].chomp,
          Time.at(match[3].to_i)]
      end
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

    def diff(commit, path = nil)
      commit = commit.id if Commit === commit
      Diff.exec(store, "git diff --full-index #{commit} #{id} -- #{path}")
    end

    def diffs(path = nil)
      diff(parent.first, path)
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

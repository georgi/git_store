class GitStore

  class Commit
    attr_accessor :store, :id, :tree, :parent, :author, :committer, :message

    def initialize(store, id = nil, data = nil)
      @store = store
      @id = id
      @parent = []

      parse(data) if data
    end

    def ==(other)
      Commit === other and id == other.id
    end

    def parse(data)
      headers, @message = data.split(/\n\n/, 2)

      headers.split(/\n/).each do |header|
        key, value = header.split(/ /, 2)
        case key
        when 'parent'
          @parent << value

        when 'author'
          @author = User.parse(value)

        when 'committer'
          @committer = User.parse(value)

        when 'tree'
          @tree = store.get(value)
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
      @id = store.put(self)
    end

    def dump
      [ "tree #{ tree.id }",
        parent.map { |parent| "parent #{parent}" },
        "author #{ author.dump }",
        "committer #{ committer.dump }",
        '',
        message ].flatten.join("\n")
    end

  end

end

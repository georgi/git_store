module Kontrol

  class Store

    module FileCache

      def real_path(path)
        "#{self.path == '/' ? '.' : self.path}/#{path}"
      end

      def changed_on_disk?(path)
        real_path = real_path(path)
        return false if not File.exist?(real_path)
        time = self.time[path]
        time.nil? or time != File.mtime(real_path)
      end

      def load_file(path, blob = tree / path)
        real_path = real_path(path)
        time[path] = File.mtime(real_path)
        self.data[path] = @reader.call(path, File.read(real_path), tree / path)
      end

    end

    include Enumerable

    attr_reader :repo, :index, :path, :tree, :data, :time, :reader, :writer

    def initialize(repo, path = '/', file_cache = false, &block)
      @repo = repo.is_a?(String) ? Grit::Repo.new(repo) : repo
      @index = @repo.index
      @path = path
      @tree = @repo.tree / path
      @data = {}
      @time = {}
      @reader = block || lambda { |path, data, blob| data }
      @writer = lambda { |path, data| data }

      extend FileCache if file_cache
      find_files_in(tree)
    end

    def [](path)
      changed_on_disk?(path) ? load_file(path) : data[path]
    end

    def []=(path, data)
      @data[path] = data
    end

    def delete(path)
      @data.delete(path)
    end

    def commit(message="")
      @data.each do |path, data|
        index.add(path, @writer.call(path, data))
      end
      
      head = repo.heads.first
      index.commit(message, head ? head.commit.id : nil)
    end

    def load
      @tree = repo.tree / path
      data.clear
      time.clear
      find_files_in(tree)
    end

    def each(&block)
      data.values.each(&block)
    end

    private

    def changed_on_disk?(path)
      false
    end
    
    def load_file(path, blob = tree / path)
      self.data[path] = reader.call(path, blob.data, blob)
    end

    def find_files_in(tree, parent = [])
      for file in tree.contents
        path = parent + [file.name]
        if file.is_a?(Grit::Tree)
          find_files_in(file, path)
        else
          name = path.join('/')
          load_file(name) if !data[name] and changed_on_disk?(name)
        end
      end
    end

  end


end

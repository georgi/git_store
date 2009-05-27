class GitStore

  # adapted from Grit
  class Diff
    attr_reader :store
    attr_reader :a_path, :b_path
    attr_reader :a_blob, :b_blob
    attr_reader :a_mode, :b_mode
    attr_reader :new_file, :deleted_file
    attr_reader :diff

    def initialize(store, a_path, b_path, a_blob, b_blob, a_mode, b_mode, new_file, deleted_file, diff)
      @store = store
      @a_path = a_path
      @b_path = b_path
      @a_blob = a_blob =~ /^0{40}$/ ? nil : store.get(a_blob)
      @b_blob = b_blob =~ /^0{40}$/ ? nil : store.get(b_blob)
      @a_mode = a_mode
      @b_mode = b_mode
      @new_file = new_file
      @deleted_file = deleted_file
      @diff = diff
    end

    def self.exec(store, cmd)
      list(store, IO.popen(cmd) { |io| io.read })
    end

    def self.list(store, text)
      lines = text.split("\n")

      diffs = []

      while !lines.empty?
        m, a_path, b_path = *lines.shift.match(%r{^diff --git a/(.+?) b/(.+)$})

        if lines.first =~ /^old mode/
          m, a_mode = *lines.shift.match(/^old mode (\d+)/)
          m, b_mode = *lines.shift.match(/^new mode (\d+)/)
        end

        if lines.empty? || lines.first =~ /^diff --git/
          diffs << Diff.new(store, a_path, b_path, nil, nil, a_mode, b_mode, false, false, nil)
          next
        end

        new_file = false
        deleted_file = false

        if lines.first =~ /^new file/
          m, b_mode = lines.shift.match(/^new file mode (.+)$/)
          a_mode = nil
          new_file = true
        elsif lines.first =~ /^deleted file/
          m, a_mode = lines.shift.match(/^deleted file mode (.+)$/)
          b_mode = nil
          deleted_file = true
        end

        m, a_blob, b_blob, b_mode = *lines.shift.match(%r{^index ([0-9A-Fa-f]+)\.\.([0-9A-Fa-f]+) ?(.+)?$})
        b_mode.strip! if b_mode

        diff_lines = []
        while lines.first && lines.first !~ /^diff/
          diff_lines << lines.shift
        end
        diff = diff_lines.join("\n")

        diffs << Diff.new(store, a_path, b_path, a_blob, b_blob, a_mode, b_mode, new_file, deleted_file, diff)
      end

      diffs
    end
  end

end

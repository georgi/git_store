
def git_show(id)
  IO.popen("git show #{id}") do |io|
    io.gets
  end
end

def git_ls_tree(id)
  lines = []
  
  IO.popen("git ls-tree #{id}") do |io|
    while line = io.gets
      lines << line.split(" ")
    end
  end

  lines
end

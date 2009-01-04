require 'git_store'
require 'benchmark'
require 'fileutils'

FileUtils.rm_rf 'repo'
FileUtils.mkpath 'repo'
Dir.chdir 'repo'

`git init`

store = GitStore.new

'a'.upto('z') do |tree|
  'aa'.upto('zz') do |key|
    store[tree, key] = (1..10).map { rand.to_s }
  end
end

store.commit

Benchmark.bm do |x|
  x.report { store['a', 'bb'] = "x" * 100; store.commit }
end


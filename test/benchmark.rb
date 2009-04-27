require 'git_store'
require 'grit'
require 'benchmark'
require 'fileutils'

REPO = '/tmp/git-store'

FileUtils.rm_rf REPO
FileUtils.mkpath REPO
Dir.chdir REPO

`git init`

store = GitStore.new(REPO)

Benchmark.bm 20 do |x|
  x.report 'store 1000 objects' do
    store.transaction { 'aaa'.upto('jjj') { |key| store[key] = rand.to_s } }
  end
  x.report 'commit one object' do
    store.transaction { store['aa'] = rand.to_s }
  end
  x.report 'load 1000 objects' do
    GitStore.new('.').values { |v| v }
  end
  x.report 'load 1000 with grit' do
    Grit::Repo.new('.').tree.contents.each { |e| e.data }
  end  
end


require "#{File.dirname(__FILE__)}/../lib/git_store"
require 'pp'

describe GitStore::Commit do
  
  REPO = '/tmp/git_store_test'

  attr_reader :store

  before(:each) do
    FileUtils.rm_rf REPO
    Dir.mkdir REPO
    Dir.chdir REPO
    `git init`
    @store = GitStore.new(REPO)
  end

  it "should dump in right format" do
    time = Time.now    
    timestamp = "#{ time.to_i } #{ time.to_s.split[4] }"

    commit = GitStore::Commit.new(nil)
    commit.tree = @store.root.id
    commit.author = "hanni #{timestamp}"
    commit.committer = "hanni #{timestamp}"
    commit.message = "This is a message"

    commit.dump.should == "tree #{@store.root.id}
author hanni #{timestamp}
committer hanni #{timestamp}

This is a message"
  end

  it "should be readable by git binary" do
    time = Time.local(2009, 4, 20)
    author = store.user_info("hans <hans@email.de>", time)
    
    store['a'] = "Yay"
    commit = store.commit("Commit Message", author, author)

    IO.popen("git log") do |io|
      io.gets.should == "commit #{commit.id}\n"
      io.gets.should == "Author: hans <hans@email.de>\n"
      io.gets.should == "Date:   Mon Apr 20 00:00:00 2009 +0200\n"
      io.gets.should == "\n"
      io.gets.should == "    Commit Message\n"
    end
  end

  it "should diff 2 commits" do
    store['x'] = 'a'
    store['y'] = "
First Line.
Second Line.
Last Line.
"
    a = store.commit

    store.delete('x')
    store['y'] = "
First Line.
Last Line.
Another Line.
"
    store['z'] = 'c'

    b = store.commit

    pp b.diff(a)
  end
  
end

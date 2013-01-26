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
    user = GitStore::User.new("hanni", "hanni@email.de", Time.now)

    commit = GitStore::Commit.new(nil)
    commit.tree = @store.root
    commit.author = user
    commit.committer = user
    commit.message = "This is a message"

    commit.dump.should == "tree #{@store.root.id}
author #{user.dump}
committer #{user.dump}

This is a message"
  end

  it "should be readable by git binary" do
    time = Time.utc(2009, 4, 20)
    author = GitStore::User.new("hans", "hans@email.de", time)
    
    store['a'] = "Yay"
    commit = store.commit("Commit Message", author, author)

    IO.popen("git log") do |io|
      io.gets.should == "commit #{commit.id}\n"
      io.gets.should == "Author: hans <hans@email.de>\n"
      io.gets.should == "Date:   Mon Apr 20 00:00:00 2009 +0000\n"
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

    diff = b.diff(a)

    diff[0].a_path.should == 'x'
    diff[0].deleted_file.should be_true

    diff[1].a_path.should == 'y'
    diff[1].diff.should == "--- a/y\n+++ b/y\n@@ -1,4 +1,4 @@\n \n First Line.\n-Second Line.\n Last Line.\n+Another Line."

    diff[2].a_path.should == 'z'
    diff[2].new_file.should be_true
  end
  
end

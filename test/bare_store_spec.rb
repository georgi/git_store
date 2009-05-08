require "#{File.dirname(__FILE__)}/../lib/git_store"
require "#{File.dirname(__FILE__)}/helper"
require 'pp'

describe GitStore do

  REPO = '/tmp/git_store_test.git'

  attr_reader :store

  before(:each) do
    FileUtils.rm_rf REPO
    Dir.mkdir REPO
    Dir.chdir REPO

    `git init --bare`
    @store = GitStore.new(REPO, 'master', true)
  end

  it 'should fail to initialize without a valid git repository' do
    lambda {
      GitStore.new('/foo', 'master', true)
    }.should raise_error(ArgumentError)
  end

  it 'should save and load entries' do
    store['a'] = 'Hello'
    store.commit
    store.load
    
    store['a'].should == 'Hello'
  end
end

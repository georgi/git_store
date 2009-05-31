require "#{File.dirname(__FILE__)}/../lib/git_store"
require "#{File.dirname(__FILE__)}/helper"
require 'pp'

describe GitStore::Tree do
  REPO = '/tmp/git_store_test'

  attr_reader :store, :tree

  before(:each) do
    FileUtils.rm_rf REPO
    Dir.mkdir REPO
    Dir.chdir REPO
    
    `git init`
    
    @store = GitStore.new(REPO)
  end

  it "should parse a table" do
    tree = GitStore::Tree.new(store)
    
    a = store.put_object("blob", "a")
    b = store.put_object("blob", "b")
    c = store.put_object("blob", "c")

    data =
      "100644 a\0#{ [a].pack("H*") }" +
      "100644 b\0#{ [b].pack("H*") }" +
      "100644 c\0#{ [c].pack("H*") }"

    tree.parse(data)

    tree.get('a').should == 'a'
    tree.get('b').should == 'b'
    tree.get('c').should == 'c'
  end

  it "should write a table" do
    tree = GitStore::Tree.new(store)
    
    tree['a'] = 'a'
    tree['b'] = 'b'
    tree['c'] = 'c'

    id = tree.write

    a = ["2e65efe2a145dda7ee51d1741299f848e5bf752e"].pack('H*')
    b = ["63d8dbd40c23542e740659a7168a0ce3138ea748"].pack('H*')
    c = ["3410062ba67c5ed59b854387a8bc0ec012479368"].pack('H*')

    data =
      "100644 a\0#{a}" +
      "100644 b\0#{b}" +
      "100644 c\0#{c}"
    
    store.get_object(id).should == ['tree', data]
  end

  it "should save trees" do
    tree = GitStore::Tree.new(store)

    tree['a'] = 'a'
    tree['b'] = 'b'
    tree['c'] = 'c'

    tree.write

    git_ls_tree(tree.id).should ==
      [["100644", "blob", "2e65efe2a145dda7ee51d1741299f848e5bf752e", "a"],
       ["100644", "blob", "63d8dbd40c23542e740659a7168a0ce3138ea748", "b"],
       ["100644", "blob", "3410062ba67c5ed59b854387a8bc0ec012479368", "c"]]      
  end
  
  it "should save nested trees" do
    tree = GitStore::Tree.new(store)
    
    tree['x/a'] = 'a'
    tree['x/b'] = 'b'
    tree['x/c'] = 'c'

    tree.write

    git_ls_tree(tree.id).should ==
      [["040000", "tree", "24e88cb96c396400000ef706d1ca1ed9a88251aa", "x"]]

    git_ls_tree("24e88cb96c396400000ef706d1ca1ed9a88251aa").should ==
      [["100644", "blob", "2e65efe2a145dda7ee51d1741299f848e5bf752e", "a"],
       ["100644", "blob", "63d8dbd40c23542e740659a7168a0ce3138ea748", "b"],
       ["100644", "blob", "3410062ba67c5ed59b854387a8bc0ec012479368", "c"]]
  end
end

require "#{File.dirname(__FILE__)}/../lib/git_store"
require "#{File.dirname(__FILE__)}/helper"

describe GitStore::Tree do
  REPO = '/tmp/git_store_test'

  before(:each) do
    FileUtils.rm_rf REPO
    Dir.mkdir REPO
    Dir.chdir REPO
    
    `git init`
    
    @store = GitStore.new(REPO)
    @tree = @store.root
  end

  it "should parse a table" do
    a = @store.put_object("blob", "a")
    b = @store.put_object("blob", "b")
    c = @store.put_object("blob", "c")

    data =
      "100644 a\0#{ [a].pack("H*") }" +
      "100644 b\0#{ [b].pack("H*") }" +
      "100644 c\0#{ [c].pack("H*") }"

    @tree.parse(data)

    @tree.get('a').should == 'a'
    @tree.get('b').should == 'b'
    @tree.get('c').should == 'c'
  end

  it "should write a table" do
    a = @store.put_object("blob", "a")
    b = @store.put_object("blob", "b")
    c = @store.put_object("blob", "c")
    
    @tree['a'] = 'a'
    @tree['b'] = 'b'
    @tree['c'] = 'c'

    id = @tree.write

    data =
      "100644 a\0#{ [a].pack("H*") }" +
      "100644 b\0#{ [b].pack("H*") }" +
      "100644 c\0#{ [c].pack("H*") }"
    
    @store.get_object(id).should == ['tree', data]
  end
  
  it "should save blobs" do
    @store['a'] = 'a'
    @store['b'] = 'b'
    @store['c'] = 'c'

    @store.commit

    a = @store.id_for('blob', 'a')
    b = @store.id_for('blob', 'b')
    c = @store.id_for('blob', 'c')

    git_show(a).should == 'a'
    git_show(b).should == 'b'
    git_show(c).should == 'c'
  end

  it "should save trees" do
    a = @store.id_for('blob', 'a')
    b = @store.id_for('blob', 'b')
    c = @store.id_for('blob', 'c')
    
    @store['a'] = 'a'
    @store['b'] = 'b'
    @store['c'] = 'c'

    @store.commit

    git_ls_tree(@store.root.id).should ==
      [
       ["100644", "blob", a, 'a'],
       ["100644", "blob", b, 'b'],
       ["100644", "blob", c, 'c']
      ]
  end
  
  it "should save nested trees" do
    a = @store.id_for('blob', 'a')
    b = @store.id_for('blob', 'b')
    c = @store.id_for('blob', 'c')
    
    @store['x/a'] = 'a'
    @store['x/b'] = 'b'
    @store['x/c'] = 'c'

    @store.commit

    git_ls_tree(@store.root['x'].id).should ==
      [
       ["100644", "blob", a, 'a'],
       ["100644", "blob", b, 'b'],
       ["100644", "blob", c, 'c']
      ]
  end

end

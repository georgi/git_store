require "#{File.dirname(__FILE__)}/../lib/git_store"
require "#{File.dirname(__FILE__)}/helper"
require 'pp'

describe GitStore do

  REPO = '/tmp/git_store_test'

  attr_reader :store

  before(:each) do
    FileUtils.rm_rf REPO
    Dir.mkdir REPO
    Dir.chdir REPO
    
    `git init`
    `git config user.name 'User Name'`
    `git config user.email 'user.name@email.com'`
    @store = GitStore.new(REPO)
  end
  
  def file(file, data)
    FileUtils.mkpath(File.dirname(file))
    open(file, 'w') { |io| io << data }
    
    `git add #{file}`
    `git commit -m 'added #{file}'`
    File.unlink(file)
  end
  
  it 'should fail to initialize without a valid git repository' do
    lambda {
      GitStore.new('/')
    }.should raise_error(ArgumentError)
  end

  it 'should find modified entries' do
    store['a'] = 'Hello'

    store.root.should be_modified

    store.commit
    
    store.root.should_not be_modified

    store['a'] = 'Bello'

    store.root.should be_modified
  end

  it 'should load a repo' do
    file 'a', 'Hello'
    file 'b', 'World'
    
    store.load

    store['a'].should == 'Hello'
    store['b'].should == 'World'
  end

  it 'should load folders' do
    file 'x/a', 'Hello'
    file 'y/b', 'World'
    
    store.load
    store['x'].should be_kind_of(GitStore::Tree)
    store['y'].should be_kind_of(GitStore::Tree)

    store['x']['a'].should == 'Hello'
    store['y']['b'].should == 'World'
  end

  it 'should load yaml' do
    file 'x/a.yml', '[1, 2, 3, 4]'

    store.load
    
    store['x']['a.yml'].should == [1,2,3,4]    
    store['x']['a.yml'] = [1,2,3,4,5]
  end

  it 'should save yaml' do
    store['x/a.yml'] = [1,2,3,4,5]      
    store['x/a.yml'].should == [1,2,3,4,5]
  end

  it 'should detect modification' do    
    store.transaction do
      store['x/a'] = 'a'
    end
    
    store.load

    store['x/a'].should == 'a'

    store.transaction do
      store['x/a'] = 'b'
      store['x'].should be_modified
      store.root.should be_modified
    end

    store.load

    store['x/a'].should == 'b'
  end

  it 'should resolve paths' do
    file 'x/a', 'Hello'
    file 'y/b', 'World'
    
    store.load
    
    store['x/a'].should == 'Hello'
    store['y/b'].should == 'World'

    store['y/b'] = 'Now this'

    store['y']['b'].should == 'Now this'        
  end

  it 'should create new trees' do
    store['new/tree'] = 'This tree'
    store['new/tree'].should == 'This tree'
  end

  it 'should delete entries' do
    store['a'] = 'Hello'
    store.delete('a')
    
    store['a'].should be_nil
  end

  it 'should have a head commit' do
    file 'a', 'Hello'

    store.load
    store.head.should_not be_nil
  end

  it 'should detect changes' do
    file 'a', 'Hello'

    store.should be_changed
  end

  it 'should rollback a transaction' do
    file 'a/b', 'Hello'
    file 'c/d', 'World'

    begin
      store.transaction do
        store['a/b'] = 'Changed'
        store['x/a'] = 'Added'
        raise
      end
    rescue
    end

    store['a/b'].should == 'Hello'
    store['c/d'].should == 'World'
    store['x/a'].should be_nil
  end

  it 'should commit a transaction' do
    file 'a/b', 'Hello'
    file 'c/d', 'World'

    store.transaction do
      store['a/b'] = 'Changed'
      store['x/a'] = 'Added'
    end

    a = git_ls_tree(store['a'].id)
    x = git_ls_tree(store['x'].id)

    a.should == [["100644", "blob", "b653cf27cef08de46da49a11fa5016421e9e3b32", "b"]]
    x.should == [["100644", "blob", "87d2b203800386b1cc8735a7d540a33e246357fa", "a"]]      

    git_show(a[0][2]).should == 'Changed'
    git_show(x[0][2]).should == 'Added'
  end
  
  it "should save blobs" do
    store['a'] = 'a'
    store['b'] = 'b'
    store['c'] = 'c'

    store.commit

    a = store.id_for('blob', 'a')
    b = store.id_for('blob', 'b')
    c = store.id_for('blob', 'c')

    git_show(a).should == 'a'
    git_show(b).should == 'b'
    git_show(c).should == 'c'
  end  

  it 'should allow only one transaction' do
    file 'a/b', 'Hello'

    ready = false

    store.transaction do
      Thread.start do
        store.transaction do
          store['a/b'] = 'Changed by second thread'
        end
        ready = true
      end
      store['a/b'] = 'Changed'
    end

    sleep 0.01 until ready

    store.load
    
    store['a/b'].should == 'Changed by second thread'
  end
  
  it 'should find all objects' do
    store.load
    store['c'] = 'Hello'
    store['d'] = 'World'
    store.commit

    store.to_a.should == [['c', 'Hello'], ['d', 'World']]
  end

  it "should load commits" do
    store['a'] = 'a'
    store.commit 'added a'

    store['b'] = 'b'
    store.commit 'added b'

    store.commits[0].message.should == 'added b'
    store.commits[1].message.should == 'added a'
  end

  it "should load tags" do
    file 'a', 'init'
    
    `git tag -m 'message' 0.1`

    store.load

    id = File.read('.git/refs/tags/0.1')
    tag = store.get(id)

    tag.type.should == 'commit'
    tag.object.should == store.head
    tag.tagger.name.should == 'User Name'
    tag.tagger.email.should == 'user.name@email.com'
    tag.message.should =~ /message/    
  end
  
end

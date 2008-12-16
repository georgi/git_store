$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))

require 'git_store'
require 'yaml'

describe GitStore do

  REPO = File.expand_path(File.dirname(__FILE__) + '/test_repo')

  before do
    FileUtils.rm_rf REPO
    Dir.mkdir REPO
    Dir.chdir REPO
    `git init`
  end

  def store
    @store or
      begin
        @store = GitStore.new(REPO)
        @store.load
        @store
      end
  end

  def file(file, data)
    FileUtils.mkpath(File.dirname(file))
    open(file, 'w') { |io| io << data }
    `git add #{file}`
    `git commit -m 'added #{file}'`
    File.unlink(file)
  end

  it 'should load a repo' do
    file 'a', 'Hello'
    file 'b', 'World'
    
    store['a'].should == 'Hello'
    store['b'].should == 'World'
  end

  it 'should load folders' do
    file 'x/a', 'Hello'
    file 'y/b', 'World'
    
    store['x'].should be_kind_of(GitStore::Tree)
    store['y'].should be_kind_of(GitStore::Tree)

    store['x']['a'].should == 'Hello'
    store['y']['b'].should == 'World'
  end

  it 'should commit added files' do
    store['c'] = 'Hello'
    store['d'] = 'World'
    store.commit

    `git checkout`

    File.should be_exist('c')
    File.should be_exist('d')

    File.read('c').should == 'Hello'
    File.read('d').should == 'World'
  end

  it 'should load yaml' do
    file 'x/a.yml', '[1, 2, 3, 4]'

    store['x']['a.yml'].should == [1,2,3,4]
    
    store['x']['a.yml'] = [1,2,3,4,5]

    store.commit
    store.load
    
    store['x']['a.yml'].should == [1,2,3,4,5]
  end

  it 'should resolv paths' do
    file 'x/a', 'Hello'
    file 'y/b', 'World'
    
    store['x/a'].should == 'Hello'
    store['y/b'].should == 'World'

    store['y/b'] = 'Now this'

    store['y']['b'].should == 'Now this'
    store.commit
    store.load

    store['y/b'].should == 'Now this'
  end

  it 'should create new trees' do
    store['new/tree'] = 'This tree'
    store['this', 'tree'] = 'Another'    
    store.commit
    store.load

    store['new/tree'].should == 'This tree'
    store['this/tree'].should == 'Another'
  end

  it 'should preserve loaded trees' do
    tree = store['tree'] = GitStore::Tree.new
    store['tree']['example'] = 'Example'
    store.commit
    store.load
    
    store['tree'].should == tree
  end

end



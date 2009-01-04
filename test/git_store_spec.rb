require 'git_store'
require 'yaml'

describe GitStore do

  REPO = File.expand_path(File.dirname(__FILE__) + '/repo')

  before do
    FileUtils.rm_rf REPO
    Dir.mkdir REPO
    Dir.chdir REPO
  end

  def store
    @store
  end
  
  def file(file, data)
    FileUtils.mkpath(File.dirname(file))
    open(file, 'w') { |io| io << data }
    if @use_git
      `git add #{file}`
      `git commit -m 'added #{file}'`
      File.unlink(file)
    end
  end

  def self.it(text, &block)
    super "#{text} with git" do
      `git init`
      @use_git = true
      @store = GitStore.new
      instance_eval(&block)
    end
    
    super "#{text} without git" do
      @use_git = false
      @store = GitStore::FileStore.new
      instance_eval(&block)
    end
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

  it 'should commit added files' do
    if @use_git      
      store.load
      store['c'] = 'Hello'
      store['d'] = 'World'
      store.commit

      `git checkout`

      File.should be_exist('c')
      File.should be_exist('d')

      File.read('c').should == 'Hello'
      File.read('d').should == 'World'
    end
  end

  it 'should load yaml' do
    file 'x/a.yml', '[1, 2, 3, 4]'

    store.load
    
    store['x']['a.yml'].should == [1,2,3,4]    
    store['x']['a.yml'] = [1,2,3,4,5]

    store.root.to_hash.should == { "x" => { "a.yml" => "--- \n- 1\n- 2\n- 3\n- 4\n- 5\n"} }

    store.commit
    store.load

    store['x']['a.yml'].should == [1,2,3,4,5]
  end

  it 'should resolv paths' do
    file 'x/a', 'Hello'
    file 'y/b', 'World'
    
    store.load
    store['x/a'].should == 'Hello'
    store['y/b'].should == 'World'

    store['y/b'] = 'Now this'

    store['y']['b'].should == 'Now this'
    store.commit
    store.load

    store['y/b'].should == 'Now this'
  end

  it 'should create new trees' do
    store.load
    store['new/tree'] = 'This tree'
    store['this', 'tree'] = 'Another'    
    store.commit
    store.load

    store['new/tree'].should == 'This tree'
    store['this/tree'].should == 'Another'
  end

  it 'should preserve loaded trees' do
    store.load
    tree = store['tree'] = GitStore::Tree.new
    store['tree']['example'] = 'Example'
    store.commit
    store.load
    
    store['tree'].should == tree
  end

end

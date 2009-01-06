Git Store - using Git as versioned data store in Ruby
=====================================================

GitStore implements a versioned data store based on the revision
management system [Git][1]. You can store object hierarchies as nested
hashes, which will be mapped on the directory structure of a git
repository. Basically GitStore checks out the repository into a
in-memory representation, which can be modified and finally committed.

GitStore supports transactions, so that updates to the store either
fail or succeed completely.

GitStore manages concurrent access by a file locking scheme. So only
one process can start a transaction at one time. This is implemented
by locking the `refs/head/<branch>.lock` file, which is also
respected by the git binary.

### Installation

GitStore can be installed as gem easily, if you have RubyGems 1.2.0:

    $ gem sources -a http://gems.github.com
    $ sudo gem install georgi-git_store

If you don't have RubyGems 1.2.0, you may download the package on the
[github page][4] and build the gem yourself:

    $ gem build git_store.gemspec
    $ sudo gem install git_store


### Usage Example

First thing you should do, is to initialize a new git repository.

    $ mkdir test
    $ cd test
    $ git init

Now you can instantiate a GitStore instance and store some data. The
data will be serialized depending on the file extension. So for YAML
storage you can use the 'yml' extension:

    @@ruby

    store = GitStore.new('/path/to/repo')

    store['users/matthias.yml'] = User.new('Matthias')
    store['pages/home.yml'] = Page.new('matthias', 'Home')

    store.commit 'Added user and page'

    # Note, that directories will be created automatically.
    # Another way to access a path is:

    store['config', 'wiki.yml'] = { 'name' => 'My Personal Wiki' }

    # Finally you can access the git store as a Hash of Hashes, but in
    # this case you have to create the Tree objects manually:

    puts store['users']['wiki.yml']['name']


### Transactions

If you access the repository from different processes, you should
write to your store using transactions. If something goes wrong inside
a transaction, all changes will be rolled back to the original state.

    @@ruby

    store = GitStore.new('/path/to/repo')

    store.transaction do
      # If an exception happens here, the transaction will be aborted.
      store['pages/home.yml'] = Page.new('matthias', 'Home')
    end

    # transaction without a block

    store.start_transaction
 
    store['pages/home.yml'] = Page.new('matthias', 'Home')

    store.rollback # This will restore the original state


### Performance

Maintaining 1000 objects in one folder seems to yield quite usable
results. If I run the following benchmark:

    @@ruby

    Benchmark.bm 20 do |x|
      x.report 'store 1000 objects' do
        store.transaction { 'aaa'.upto('jjj') { |key| store[key] = rand.to_s } }
      end
      x.report 'commit one object' do
        store.transaction { store['aa'] = rand.to_s }
      end
      x.report 'load 1000 objects' do
        GitStore.new('.')
      end
      x.report 'load 1000 with grit' do
        Grit::Repo.new('.').tree.contents.each { |e| e.data }
      end  
    end


I get following results:

                              user     system      total        real
    store 1000 objects    4.150000   0.880000   5.030000 (  5.035804)
    commit one object     0.070000   0.020000   0.090000 (  0.082252)
    load 1000 objects     0.630000   0.120000   0.750000 (  0.750765)
    load 1000 with grit   1.960000   0.260000   2.220000 (  2.228583)


In a real world scenario, you should partition your data. For example,
my blog engine [Shinmun][7], stores posts in folders by month.

One nice thing about the results is, that GitStore loads large
directories three times faster than [Grit][2].


### Where is my data?

When you call the `commit` method, your data is written back straight
into the git repository. No intermediate file representation. So if
you want to look into your data, you can use some git browser like
[git-gui][6] or just checkout the files:

    $ git checkout


### Development Mode

There is also some kind of development mode, which is convenient to
use. Imagine you are tweaking the design of your blog, which is
storing its pages in a GitStore. You don't want to commit each change
to some change in your browser. FileStore helps you here:

    @@ruby

    store = GitStore::FileStore.new('.')

    # Access the file 'posts/2009/1/git-store.md'

    p store['posts', 2009, 1, 'git-store.md']


FileStore forbids you to write to the disk, as this makes no sense. If
you want to store something programmatically, you have to use the real
GitStore.


### Iteration

Iterating over the data objects is quite easy. Furthermore you can
iterate over trees and subtrees, so you can partition your data in a
meaningful way. For example you may separate the config files and the
pages of a wiki:

    @@ruby

    store['pages/home.yml'] = Page.new('matthias', 'Home')
    store['pages/about.yml'] = Page.new('matthias', 'About')
    store['pages/links.yml'] = WikiPage.new('matthias', 'Links')
    store['config/wiki.yml'] = { 'name' => 'My Personal Wiki' }

    store.each { |obj| ... } # yields all pages and the config file
    store['pages'].each { |page| ... } # yields only the pages


### Serialization

Serialization is dependent on the filename extension. You can add more
handlers if you like, the interface is like this:

    @@ruby

    class YAMLHandler
      def read(path, data)
        YAML.load(data)
      end
   
      def write(path, data)
        data.to_yaml
      end    
    end

    GitStore::Handler['yml'] = YAMLHandler.new


Shinmun uses its own handler for files with `md` extension:

    @@ruby

    class PostHandler
      def read(path, data)
        Post.new(:path => path, :src => data)
      end
   
      def write(path, post)
        post.dump
      end    
    end

    GitStore::Handler['md'] = PostHandler.new


### GitStore on GitHub

Download or fork the project on its [Github page][5]


### Related Work

John Wiegley already has done [something similar for Python][4].



[1]: http://git.or.cz/
[2]: http://github.com/mojombo/grit
[4]: http://www.newartisans.com/blog_files/git.versioned.data.store.php
[5]: http://github.com/georgi/git_store
[6]: http://www.kernel.org/pub/software/scm/git/docs/git-gui.html
[7]: http://www.matthias-georgi.de/shinmun

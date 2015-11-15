Git Store - using Git as versioned data store in Ruby
=====================================================

GitStore implements a versioned data store based on the revision
management system [Git][1]. You can store object hierarchies as nested
hashes, which will be mapped on the directory structure of a git
repository. Basically GitStore checks out the repository into a
in-memory representation, which can be modified and finally committed.

GitStore supports transactions, so that updates to the store either
fail or succeed completely.

### Installation

GitStore can be installed as gem easily:

    $ gem sources -a http://gems.github.com
    $ sudo gem install georgi-git_store

### Usage Example

First thing you should do, is to initialize a new git repository.

    $ mkdir test
    $ cd test
    $ git init

Now you can instantiate a GitStore instance and store some data. The
data will be serialized depending on the file extension. So for YAML
storage you can use the 'yml' extension:

    store = GitStore.new('/path/to/repo')

    store['users/matthias.yml'] = User.new('Matthias')
    store['pages/home.yml'] = Page.new('matthias', 'Home')

    store.commit 'Added user and page'

### Transactions

GitStore manages concurrent access by a file locking scheme. So only
one process can start a transaction at one time. This is implemented
by locking the `refs/head/<branch>.lock` file, which is also
respected by the git binary.

If you access the repository from different processes or threads, you
should write to the store using transactions. If something goes wrong
inside a transaction, all changes will be rolled back to the original
state.

    store = GitStore.new('/path/to/repo')

    store.transaction do
      # If an exception happens here, the transaction will be aborted.
      store['pages/home.yml'] = Page.new('matthias', 'Home')
    end


A transaction without a block looks like this:

    store.start_transaction
 
    store['pages/home.yml'] = Page.new('matthias', 'Home')

    store.rollback # This will restore the original state


### Data Storage

When you call the `commit` method, your data is written back straight
into the git repository. No intermediate file representation. So if
you want to have a look at your data, you can use a git browser like
[git-gui][6] or checkout the files:

    $ git checkout


### Iteration

Iterating over the data objects is quite easy. Furthermore you can
iterate over trees and subtrees, so you can partition your data in a
meaningful way. For example you may separate the config files and the
pages of a wiki:

    store['pages/home.yml'] = Page.new('matthias', 'Home')
    store['pages/about.yml'] = Page.new('matthias', 'About')
    store['config/wiki.yml'] = { 'name' => 'My Personal Wiki' }

    # Enumerate all objects
    store.each { |obj| ... } 

    # Enumerate only pages
    store['pages'].each { |page| ... }


### Serialization

Serialization is dependent on the filename extension. You can add more
handlers if you like, the interface is like this:

    class YAMLHandler
      def read(data)
        YAML.load(data)
      end
   
      def write(data)
        data.to_yaml
      end    
    end

Shinmun uses its own handler for files with `md` extension:

    class PostHandler
      def read(data)
        Post.new(:src => data)
      end
   
      def write(post)
        post.dump
      end    
    end

    store = GitStore.new('.')
    store.handler['md'] = PostHandler.new


### GitStore on GitHub

Download or fork the project on its [Github page][5]



[1]: http://git.or.cz/
[2]: http://github.com/mojombo/grit
[5]: http://github.com/georgi/git_store
[6]: http://www.kernel.org/pub/software/scm/git/docs/git-gui.html
[7]: http://www.matthias-georgi.de/shinmun

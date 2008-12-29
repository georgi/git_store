Git Store - using Git as versioned data store in Ruby
=====================================================

GitStore is a small Ruby library, providing an easy interface to the
version control system [Git][1]. It aims to use Git as a versioned
data store much like the well known PStore. Basically GitStore checks
out the repository into a in-memory representation, which can be
modified and finally committed. In this way your data is stored in a
folder structure and can be checked out and examined, but the
application may access the data in a convenient hash-like way. This
library is based on [Grit][2], the main technology behind [GitHub][3].


## Installation

GitStore can be installed as gem easily, if you have RubyGems 1.2.0:

    $ gem sources -a http://gems.github.com (you only have to do this once)
    $ sudo gem install mojombo-grit georgi-git_store

If you don't have RubyGems 1.2.0, you may download the package on the
[github page][4] and build the gem yourself:

    $ gem build git_store.gemspec
    $ sudo gem install git_store


## Usage Example

First thing you should do, is to initialize a new git repository.

    $ mkdir test
    $ cd test
    $ git init

Now you can instantiate a GitStore instance and store some data. The
data will be serialized depending on the file extension. So for YAML
storage you can use the 'yml' extension:

    class WikiPage < Struct.new(:author, :title, :body); end
    class User < Struct.new(:name); end

    store = GitStore.new('.')

    store['users/matthias.yml'] = User.new('Matthias')
    store['pages/home.yml'] = WikiPage.new('matthias', 'Home', 'This is the home page...')

    store.commit 'Added user and page'

Note that directories will be created automatically.

Another way to access a path is:

    store[config', 'wiki.yml'] = { 'name' => 'My Personal Wiki' }

Finally you can access the git store as a Hash of Hashes, but in this
case you have to create the Tree objects manually:

    store['users'] = GitStore::Tree.new
    store['users']['matthias.yml'] = User.new('Matthias')

## Where is my data?

When you call the `commit` method, your data is written back straight
into the git repository. No intermediate file representation. So if
you want to look into your data, you can use some git browser like
[git-gui][6] or just checkout the files:

    $ git checkout


## Iteration

Iterating over the data objects is quite easy. Furthermore you can
iterate over trees and subtrees, so you can partition your data in a
meaningful way. For example you may separate the config files and the
pages of a wiki:

    store['pages/home.yml'] = WikiPage.new('matthias', 'Home', 'This is the home page...')
    store['pages/about.yml'] = WikiPage.new('matthias', 'About', 'About this site...')
    store['pages/links.yml'] = WikiPage.new('matthias', 'Links', 'Some useful links...')
    store['config/wiki.yml'] = { 'name' => 'My Personal Wiki' }

    store.each { |obj| ... } # yields all pages and the config hash
    store['pages'].each { |page| ... } # yields only the pages


## Serialization

Serialization is dependent on the filename extension. You can add more
handlers if you like, the interface is like this:

    class YAMLHandler
      def read(id, name, data)
        YAML.load(data)
      end
   
      def write(data)
        data.to_yaml
      end    
    end

    GitStore::Handler['yml'] = YAMLHandler.new


Shinmun uses its own handler for files with `md` extension:

    class PostHandler
      def read(name, data)
        Post.new(:filename => name, :src => data)
      end
   
      def write(post)
        post.dump
      end    
    end

    GitStore::Handler['md'] = PostHandler.new


## Related Work

John Wiegley already has done [something similar for Python][4]. His
implementation has its own git interface, GitStore uses the wonderful
[Grit][2] library.

[1]: http://git.or.cz/
[2]: http://github.com/mojombo/grit
[3]: http://github.com/
[4]: http://www.newartisans.com/blog_files/git.versioned.data.store.php
[5]: http://github.com/georgi/git_store
[6]: http://www.kernel.org/pub/software/scm/git/docs/git-gui.html

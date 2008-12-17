GitStore - using Git as versioned data store in Ruby
====================================================

GitStore is a small Ruby library, providing an easy interface to the
version control system [Git][1]. It aims to use Git as a versioned
data store much like the well known PStore. Basically GitStore checks
out the repository into a in-memory representation, which can be
modified and finally committed. In this way your data is stored in a
folder structure and can be checked out and examined, but the
application may access the data in a convenient hash-like way.

This library is based on [Grit][2], the main technology behind
[GitHub][3].

## Usage Example

First thing you should do, is to initialize a new git repository.

    git init

Now you can instantiate a GitStore instance and store some data. The
data will be serialized depending on the file extension. So for YAML
storage you can use the 'yml' extension:

    class WikiPage < Struct.new(:author, :title, :body); end
    class User < Struct.new(:name); end

    store = GitStore.new('.')

    store['users/matthias.yml'] = User.new('Matthias')
    store['pages/home.yml'] = WikiPage.new('matthias', 'Home', 'This is the home page...')

    store.commit 'Added user and page'

Note that direcories will be created automatically by using the path
syntax. Same for multi arguments hash syntax:

    store[config', 'wiki.yml'] = { 'name' => 'My Personal Wiki' }

In this case the directory config is created automatically and
the file wiki.yml contains be the YAML representation of the given Hash.

## Iteration

Iterating over the stored datat is one of the common use cases, so
this one is really easy and scales well at the same time, if you user
a clever directory structure:

    store['pages/home.yml'] = WikiPage.new('matthias', 'Home', 'This is the home page...')
    store['pages/about.yml'] = WikiPage.new('matthias', About', 'About this site...')
    store['pages/links.yml'] = WikiPage.new('matthias', 'Links', 'Some useful links...')
    store['config/wiki.yml'] = { 'name' => 'My Personal Wiki' }

    store.each { |obj| ... } # yields all pages and the config hash
    store['pages'].each { |page| ... } # yields only the pages

## References

John Wiegley already has done [something similar for Python][4]. His
implementation has its own git interface, GitStore uses the wonderful
[Grit][2] library.

[1]: http://git.or.cz/
[2]: http://github.com/mojombo/grit/tree/master
[3]: http://github.com/
[4]: http://www.newartisans.com/blog_files/git.versioned.data.store.php

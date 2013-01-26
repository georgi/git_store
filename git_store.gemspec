Gem::Specification.new do |s|
  s.name = 'git_store'
  s.version = '0.3.3'
  s.summary = 'a simple data store based on git'
  s.author = 'Matthias Georgi'
  s.email = 'matti.georgi@gmail.com'
  s.homepage = 'http://georgi.github.com/git_store'
  s.description = <<END
GitStore implements a versioned data store based on the revision
management system Git. You can store object hierarchies as nested
hashes, which will be mapped on the directory structure of a git
repository. GitStore checks out the repository into a in-memory
representation, which can be modified and finally committed.
END
  s.require_path = 'lib'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.md']  
  s.files = %w{
.gitignore
LICENSE
README.md
Rakefile
git_store.gemspec
lib/git_store.rb
lib/git_store/blob.rb
lib/git_store/commit.rb
lib/git_store/diff.rb
lib/git_store/handlers.rb
lib/git_store/pack.rb
lib/git_store/tag.rb
lib/git_store/tree.rb
lib/git_store/user.rb
test/bare_store_spec.rb
test/benchmark.rb
test/commit_spec.rb
test/git_store_spec.rb
test/tree_spec.rb
}
end


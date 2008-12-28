Gem::Specification.new do |s|
  s.name = 'git_store'
  s.version = '0.1.1'
  s.date = '2008-12-17'
  s.summary = 'a simple data store based on git'
  s.author = 'Matthias Georgi'
  s.email = 'matti.georgi@gmail.com'
  s.homepage = 'http://github.com/georgi/git_store'  
  s.description = 'A simple git based data store'
  s.require_path = 'lib'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.md']  
  s.files = %w{
.gitignore
LICENSE
README.md
git_store.gemspec
lib/git_store.rb
spec/git_store_spec.rb
}
end


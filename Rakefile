require 'rake'
require 'rdoc/task'
require 'rspec/core/rake_task'

desc "Run all specs"
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = 'test/**/*_spec.rb'
  spec.rspec_opts = ['--backtrace']
end

desc "Generate the RDoc"
RDoc::Task.new do |rdoc|
  files = ["README.md", "LICENSE", "lib/**/*.rb"]
  rdoc.rdoc_files.include(files)
  rdoc.main = "README.md"
  rdoc.title = "Git Store - using Git as versioned data store in Ruby"
end

desc "Run the rspec"
task :default => :spec

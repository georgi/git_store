require 'rake'
require "rake/rdoctask"

begin
  require 'spec/rake/spectask'
rescue LoadError
  puts <<-EOS
To use rspec for testing you must install the rspec gem:
    gem install rspec
EOS
  exit(0)
end

desc "Run all specs"
Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_opts = ['-cfs']
  t.ruby_opts = ['-Ilib']
  t.spec_files = FileList['test/**/*_spec.rb']
end

desc "Print SpecDocs"
Spec::Rake::SpecTask.new(:doc) do |t|
  t.spec_opts = ["--format", "specdoc"]
  t.spec_files = FileList['test/*_spec.rb']
end

desc "Generate the RDoc"
Rake::RDocTask.new do |rdoc|
  files = ["README.md", "LICENSE", "lib/**/*.rb"]
  rdoc.rdoc_files.add(files)
  rdoc.main = "README.md"
  rdoc.title = "Git Store - using Git as versioned data store in Ruby"
end

desc "Run the rspec"
task :default => :spec

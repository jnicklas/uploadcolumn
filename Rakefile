require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'spec/rake/spectask'

file_list = FileList['spec/*_spec.rb']

namespace :spec do
  desc "Run all examples with RCov"
  Spec::Rake::SpecTask.new('rcov') do |t|
    t.spec_files = file_list
    t.rcov = true
    t.rcov_dir = "doc/coverage"
    t.rcov_opts = ['--exclude', 'spec']
  end
  
  desc "Generate an html report"
  Spec::Rake::SpecTask.new('report') do |t|
    t.spec_files = file_list
    t.rcov = true
    t.rcov_dir = "doc/coverage"
    t.rcov_opts = ['--exclude', 'spec']
    t.spec_opts = ["--format", "html:doc/reports/specs.html"]
    t.fail_on_error = false
  end
  
  desc "heckle all"
  task :heckle => [ 'spec:heckle:uploaded_file', 'spec:heckle:sanitized_file' ]
  
  namespace :heckle do
    desc "Heckle UploadedFile"
    Spec::Rake::SpecTask.new('uploaded_file') do |t|
      t.spec_files = [ File.join(File.dirname(__FILE__), *%w[spec uploaded_file_spec.rb]) ]
      t.spec_opts = ["--heckle", "UploadColumn::UploadedFile"]
    end
    
    desc "Heckle SanitizedFile"
    Spec::Rake::SpecTask.new('sanitized_file') do |t|
      t.spec_files = [ File.join(File.dirname(__FILE__), *%w[spec uploaded_file_spec.rb]) ]
      t.spec_opts = ["--heckle", "UploadColumn::SanitizedFile"]
    end
  end

end


desc 'Default: run unit tests.'
task :default => 'spec:rcov'

namespace "doc" do
  
  desc 'Generate documentation for the UploadColumn plugin.'
  Rake::RDocTask.new(:normal) do |rdoc|
    rdoc.rdoc_dir = 'doc/rdoc'
    rdoc.title    = 'UploadColumn'
    rdoc.options << '--line-numbers' << '--inline-source'
    rdoc.rdoc_files.include('README')
    rdoc.rdoc_files.include('lib/**/*.rb')
  end
  
  desc 'Generate documentation for the UploadColumn plugin using the allison template.'
  Rake::RDocTask.new(:allison) do |rdoc|
    rdoc.rdoc_dir = 'doc/rdoc'
    rdoc.title    = 'UploadColumn'
    rdoc.options << '--line-numbers' << '--inline-source'
    rdoc.rdoc_files.include('README')
    rdoc.rdoc_files.include('lib/**/*.rb')
    rdoc.main = "README" # page to start on
    rdoc.template = "~/Projects/allison2/allison/allison.rb"
  end
end
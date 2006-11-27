RAILS_ROOT = File.dirname(__FILE__)

require 'test/unit'
require 'rubygems'
require_gem 'activesupport'
require_gem 'activerecord'
require_gem 'actionpack'
require 'stringio'
require 'breakpoint'
require 'test_help'

#:nodoc:

# Bootstrap the database
require 'logger'
ActiveRecord::Base.logger = Logger.new("debug.log")

config = YAML::load(File.open("#{RAILS_ROOT}/../../../../config/database.yml"))
ActiveRecord::Base.establish_connection( config["test"] )

$: << "../lib"

ActiveRecord::Base.send(:include, UploadColumn)


# we need to be able to change the original_filename, so that we can test
# if the name were some crazy stuff....
class ActionController::TestUploadedFile
  attr_writer :original_filename
end

class Test::Unit::TestCase
  private
  
  def uploaded_file(basename, mime_type = nil, filename = nil)
    ActionController::TestProcess # This is a hack, do not remove :P
    file = ActionController::TestUploadedFile.new(
      file_path( basename ), 
      mime_type.to_s
    )
    file.original_filename = filename if filename
    return file
  end
  
  def uploaded_stringio( basename, mime_type = nil, filename = nil)
    filename ||= basename
    if basename
      t = StringIO.new( IO.read( file_path( basename ) ) )
    else
      t = StringIO.new
    end
    (class << t; self; end).class_eval do
      define_method(:local_path) { "" }
      define_method(:original_filename) {filename}
      define_method(:content_type) {mime_type}
    end  
    return t
  end
  
  def assert_identical( actual, expected, message = nil )
    message ||= "files #{actual} and #{expected} are not identical."
    assert FileUtils.identical?(actual, expected), message
  end
  
  def assert_not_identical( actual, expected, message = nil )
    message ||= "files #{actual} and #{expected} are not identical."
    assert !FileUtils.identical?(actual, expected), message
  end
  
  def file_path( basename )
    File.join(RAILS_ROOT, 'fixtures', basename)
  end
  
  def read_image(path)
    Magick::Image::read(path).first
  end

  def assert_max_image_size(img, cols, rows)
    assert img.columns <= cols, "img has #{img.columns} columns, expected: #{cols}"
    assert img.rows <= rows, "img has #{img.rows} rows, expected: #{rows}"
  end
  
  def assert_image_size(img, cols, rows)
    assert img.columns == cols, "img has #{img.columns} columns, expected: #{cols}"
    assert img.rows == rows, "img has #{img.rows} rows, expected: #{rows}"
  end

end

class TestMigration < ActiveRecord::Migration
  def self.up
    create_table :entries do |t|
      t.column :image, :string
      t.column :file, :string
    end
    
    create_table :movies do |t|
      t.column :movie, :string
      t.column :name, :string
      t.column :description, :text
    end
  end

  def self.down
    drop_table :entries
    drop_table :movies
  end
end

ActiveRecord::Migration.verbose = false

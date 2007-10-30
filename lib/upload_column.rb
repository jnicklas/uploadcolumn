require File.join(File.dirname(__FILE__), 'upload_column', 'sanitized_file.rb')
require File.join(File.dirname(__FILE__), 'upload_column', 'uploaded_file.rb')
require File.join(File.dirname(__FILE__), 'upload_column', 'magic_columns.rb')
require File.join(File.dirname(__FILE__), 'upload_column', 'upload_column.rb')
require File.join(File.dirname(__FILE__), 'upload_column', 'manipulators', 'rmagick.rb')
require File.join(File.dirname(__FILE__), 'upload_column', 'manipulators', 'image_science.rb')
require File.join(File.dirname(__FILE__), 'upload_column', 'configuration.rb')


ActiveRecord::Base.send(:include, UploadColumn)
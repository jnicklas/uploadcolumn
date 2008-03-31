# plugin init file for rails
# this file will be picked up by rails automatically and
# add the upload_column extensions to rails

require File.join(File.dirname(__FILE__), 'lib', 'upload_column')
require File.join(File.dirname(__FILE__), 'lib', 'upload_column', 'rails', 'upload_column_helper')
require File.join(File.dirname(__FILE__), 'lib', 'upload_column', 'rails', 'action_controller_extension')
require File.join(File.dirname(__FILE__), 'lib', 'upload_column', 'rails', 'asset_tag_extension')

Mime::Type.register "image/png", :png
Mime::Type.register "image/jpeg", :jpg
Mime::Type.register "image/gif", :gif

UploadColumn::Root = RAILS_ROOT
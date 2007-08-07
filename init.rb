# plugin init file for rails
# this file will be picked up by rails automatically and
# add the upload_column extensions to rails

require File.join(File.dirname(__FILE__), 'lib', 'upload_column')
require File.join(File.dirname(__FILE__), 'lib', 'upload_column', 'upload_column_helper')
require File.join(File.dirname(__FILE__), 'lib', 'upload_column', 'upload_column_render_helper')

ActionView::Base.send(:include, UploadColumnHelper)
ActionController::Base.send(:include, UploadColumnRenderHelper)

Mime::Type.register "image/png", :png
Mime::Type.register "image/jpeg", :jpg
Mime::Type.register "image/gif", :gif

UploadColumn::Root = RAILS_ROOT
# plugin init file for rails
# this file will be picked up by rails automatically and
# add the file_column extensions to rails

ActiveRecord::Base.send(:include, UploadColumn)
ActionView::Base.send(:include, UploadColumnHelper)
ActionController::Base.send(:include, UploadColumnRenderHelper)
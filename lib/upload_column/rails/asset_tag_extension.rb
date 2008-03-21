module UploadColumn::AssetTagExtension
  
  def self.included(base)
    base.alias_method_chain :image_tag, :uploaded_file_check
  end
  
  def image_tag_with_uploaded_file_check(source, options = {})
    if(source.respond_to?(:public_path))
      image_tag_without_uploaded_file_check(source.public_path, options)
    else
      image_tag_without_uploaded_file_check(source, options)
    end
  end
  
end

ActionView::Helpers::AssetTagHelper.send(:include, UploadColumn::AssetTagExtension)
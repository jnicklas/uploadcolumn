module UploadColumn::ActionControllerExtension

  def self.included(base)
    base.alias_method_chain :url_for, :uploaded_file_check
    base.helper_method :url_for_path
  end
  
  protected
  
  def url_for_with_uploaded_file_check(options = {}, *parameters_for_method_reference)
    if(options.respond_to?(:public_path))
      options.public_path
    else
      url_for_without_uploaded_file_check(options || {}, *parameters_for_method_reference)
    end
  end
  
  def url_for_path(path)
    request.protocol + request.host_with_port + path
  end
  
  # You can use +render_image+ in your controllers to render an image
  #     def picture
  #       @user = User.find(params[:id])
  #       render_image @user.picture
  #     end
  # This of course, is not very useful at all (you could simply have linked to the image itself),
  # However it is even possible to pass a block to render_image that allows manipulation using
  # RMagick, here the fun begins:
  #     def solarize_picture
  #       @user = User.find(params[:id])
  #       render_image @user.picture do |img|
  #         img = img.segment
  #         img.solarize
  #       end
  #     end
  # Note that like in UploadColumn::BaseUploadedFile.process you will need to 'carry' the image
  # since most Rmagick methods do not modify the image itself but rather return the result of the
  # transformation.
  #
  # Instead of passing an upload_column object to +render_image+ you can even pass a path String,
  # if you do you will have to pass a :mime-type option as well though.
  def render_image( file, options = {} )
      format = if options.is_a?(Hash) then options[:force_format] else nil end
      mime_type = if options.is_a?(String) then options else options[:mime_type] end
      mime_type ||= file.mime_type
      path = if file.is_a?( String ) then file else file.path end
      headers["Content-Type"] = mime_type unless format
      
      if block_given? or format
        img = ::Magick::Image::read(path).first
        img = yield( img ) if block_given?
        img.format = format.to_s.upcase if format
        render :text => img.to_blob, :layout => false
      else
        send_file( path )
      end
  end
end

ActionController::Base.send(:include, UploadColumn::ActionControllerExtension)
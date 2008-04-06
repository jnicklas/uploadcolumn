module UploadColumnHelper

  # Returns an input tag of the "file" type tailored for accessing an upload_column field
  # (identified by method) on an object assigned to the template (identified by object).
  # Additional options on the input tag can be passed as a hash with options.
  #
  # Example (call, result)
  #     upload_column_field( :user, :picture )
  #       <input id="user_picture_temp" name="user[picture_temp]" type="hidden" />
  #       <input id="user_picture" name="user[picture]" size="30" type="file" />
  #
  # Note: if you use file_field instead of upload_column_field, the file will not be
  # stored across form redisplays.
  def upload_column_field(object, method, options={})
    result = ActionView::Helpers::InstanceTag.new(object, method, self).to_input_field_tag("file", options)
    result << ActionView::Helpers::InstanceTag.new(object, method.to_s+"_temp", self).to_input_field_tag("hidden", {})
  end
  
  # A helper method for creating a form tag to use with uploadng files,
  # it works exactly like Rails' form_tag, except that :multipart is always true
  def upload_form_tag(url_for_options = {}, options = {}, *parameters_for_url, &proc)
    options[:multipart] = true
    form_tag( url_for_options, options, *parameters_for_url, &proc )
  end
  
  # A helper method for creating a form tag to use with uploadng files,
  # it works exactly like Rails' form_for, except that :multipart is always true
  def upload_form_for(*args, &block)
    options = args.extract_options!
    options[:html] ||= {}
    options[:html][:multipart] = true
    args.push(options)
    
    form_for(*args, &block)
  end

  # Returns an image tag using a URL created by the set of +options+. Accepts the same options
  # as ActionController::Base#url_for. It's also possible to pass a string instead of an options
  # hash.
  #
  # Example
  #     image( :action => "solarize_picture", :id => @user )
  # Use this in conjunction with UploadColumnRenderHelper.render_image to output dynamically
  # rendered version of your RMagick manipulated images.
  def image(options = {}, html_options = {})
    html_options[:src] = if options.is_a?(String) then options else self.url_for(options) end
    html_options[:alt] ||= File.basename(html_options[:src], '.*').split('.').first.capitalize

    if html_options[:size]
      html_options[:width], html_options[:height] = html_options[:size].split("x")
      html_options.delete :size
    end

    tag("img", html_options)
  end

end

class ActionView::Helpers::FormBuilder #:nodoc:
  self.field_helpers += ['upload_column_field']  
  def upload_column_field(method, options = {})
    @template.send(:upload_column_field, @object_name, method, options.merge(:object => @object))
  end 
end

ActionView::Base.send(:include, UploadColumnHelper)
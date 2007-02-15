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
  # it works exactly like Rails' start_form_tag, except that :multipart is always true
  def upload_form_tag(url_for_options = {}, options = {}, *parameters_for_url, &proc)
    options[:multipart] = true
    form_tag( url_for_options, options, *parameters_for_url, &proc )
  end
  
  # What? You cry, files cannot be uploaded using JavaScript! Well,
  # you're right. But you see, this method will use an iframe, clever no? What this means
  # for you is that you'll probably want to fetch the respond_to_parent plugin, that will
  # make handling this a breeze.
  # You can pass the following keys to options
  # [+url+] The target URL
  # [+fallback+] If JavaScript is disabled, the fallback address will be used, use Rails' ActionController::Base.url_for syntax.
  # [+force_html+] This will set the target attribute via HTML instead of JS, so if JS is disabled, it will submit to the iframe anyway (defaults to false)
  # [+html+] HTML options for the form tag
  # [+iframe+] HTML options for the iframe tag
  # [+before+] JavaScript called before the form is sent (via onsubmit)
  # Note: You can NOT use the normal prototype callbacks in this function, since it does not use
  # Ajax to upload the form.
  def remote_upload_form_tag( options = {}, &block )
    framename = "uf#{Time.now.usec}#{rand(1000)}"
    iframe_options = {
      "style" => "position: absolute; width: 0; height: 0; border: 0;",
      "id" => framename,
      "name" => framename,
      "src" => ''
    }
    iframe_options = iframe_options.merge(options[:iframe].stringify_keys) if options[:iframe]
    
    form_options = { "method" => "post" }
    form_options = form_options.merge(options[:html].stringify_keys) if options[:html]

    form_options["enctype"] = "multipart/form-data"

    url = url_for(options[:url])

    if options[:force_html]
      form_options["action"] = url_for(options[:url])
      form_options["target"] = framename
    else
      form_options["action"] = if options[:fallback] then url_for(options[:fallback]) else url end
      form_options["onsubmit"] = %(this.action = '#{escape_javascript( url )}'; this.target = '#{escape_javascript( framename )}';)
      form_options["onsubmit"] << options[:before] if options[:before]
    end
    if block_given?
      content = capture(&block)
      concat(tag( :iframe, iframe_options, true ) + '</iframe>', block.binding)
      form_tag( url, form_options, &block )
    else
      tag( :iframe, iframe_options, true ) + '</iframe>' + form_tag( form_options[:action], form_options, &block )
    end
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

class ActionView::Helpers::FormBuilder
  self.field_helpers += ['upload_column_field']  
  def upload_column_field(method, options = {})
    @template.send(:upload_column_field, @object_name, method, options.merge(:object => @object))
  end 
end

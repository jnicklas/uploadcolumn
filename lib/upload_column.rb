require 'fileutils'
require 'tempfile'
require 'RMagick'
    
module UploadColumn
  def self.append_features(base) #:nodoc:
    super
    base.extend(ClassMethods)
  end

  # default mapping of mime-types to file extensions. FileColumn will try to
  # rename a file to the correct extension if it detects a known mime-type
  MIME_EXTENSIONS = {
    "image/gif" => "gif",
    "image/jpeg" => "jpg",
    "image/pjpeg" => "jpg",
    "image/x-png" => "png",
    "image/jpg" => "jpg",
    "image/png" => "png",
    "application/x-shockwave-flash" => "swf",
    "application/pdf" => "pdf",
    "application/pgp-signature" => "sig",
    "application/futuresplash" => "spl",
    "application/msword" => "doc",
    "application/postscript" => "ps",
    "application/x-bittorrent" => "torrent",
    "application/x-dvi" => "dvi",
    "application/x-gzip" => "gz",
    "application/x-ns-proxy-autoconfig" => "pac",
    "application/x-shockwave-flash" => "swf",
    "application/x-tgz" => "tar.gz",
    "application/x-tar" => "tar",
    "application/zip" => "zip",
    "audio/mpeg" => "mp3",
    "audio/x-mpegurl" => "m3u",
    "audio/x-ms-wma" => "wma",
    "audio/x-ms-wax" => "wax",
    "audio/x-wav" => "wav",
    "image/x-xbitmap" => "xbm",             
    "image/x-xpixmap" => "xpm",             
    "image/x-xwindowdump" => "xwd",             
    "text/css" => "css",             
    "text/html" => "html",                          
    "text/javascript" => "js",
    "text/plain" => "txt",
    "text/xml" => "xml",
    "video/mpeg" => "mpeg",
    "video/quicktime" => "mov",
    "video/x-msvideo" => "avi",
    "video/x-ms-asf" => "asf",
    "video/x-ms-wmv" => "wmv"
  }
  
  IMAGE_MIME_EXTENSIONS = {
    "image/gif" => "gif",
    "image/jpeg" => "jpg",
    "image/pjpeg" => "jpg",
    "image/x-png" => "png",
    "image/jpg" => "jpg",
    "image/png" => "png", 
  }
  
  IMAGE_EXTENSIONS = Set.new( [ "jpg", "jpeg", "png", "gif" ] )

  EXTENSIONS = Set.new MIME_EXTENSIONS.values
  EXTENSIONS.merge %w(jpeg)

  # default options. You can override these with +file_column+'s +options+ parameter
  DEFAULT_OPTIONS = {
    :root_path => File.join(RAILS_ROOT, "public"),
    :web_root => "",
    :mime_extensions => MIME_EXTENSIONS,
    :extensions => EXTENSIONS,
    :fix_file_extensions => true,
    :store_dir => nil,
    :store_dir_append_id => true,
    :tmp_dir => "tmp",
    :old_files => :accumulate,
    :validate_integrity => true,
    :file_exec => 'file'
  }.freeze

  # = Basics
  # When you call an upload_column field, an instance of this class will be returned.
  # 
  # Suppose a +User+ model has a +picture+ upload_column, like so:
  #     class User < ActiveRecord::Base
  #       upload_column :picture
  #     end
  # Now in our controller we did:
  #     @user = User.find(params[:id])
  # We could then access the file:
  #     @user.picture.url
  # Which would output the url to the file (assuming it is stored in /public/)
  # = Versions
  # If we had instead added different versions in our model
  #     upload_column :picture, :versions => [:thumb, :large]
  # Then we could access them like so:
  #     @user.picture.thumb.url
  class UploadedFile

    attr_accessor :options, :dir, :mime_type
    attr_reader :instance, :attribute, :versions, :suffix, :options

    private :dir=
    private :mime_type=

    def initialize(options, instance, attribute, dir = nil, filename = nil, suffix = nil)
      options = DEFAULT_OPTIONS.merge(options)
  
      @options = options
      @instance = instance
      @attribute = attribute
      @filename = filename || instance[attribute]
      @suffix = suffix
  
      if dir
        @dir = dir
      else
        @dir = self.instance.id.to_s if options[:store_dir_append_id]
      end
      
      unless options[:web_root].blank?
        options[:web_root] = '/' << options[:web_root] unless options[:web_root] =~ %r{^/}
      end
      
      unless options[:tmp_dir].blank?
        options[:tmp_dir][0] = '' if options[:tmp_dir] =~ %r{^/}
      end
  
      if suffix.nil? and options[:versions]
        @versions = {}
        for version in options[:versions]
          version = version[0] if version.is_a?( Array )
          @versions[version.to_sym] = self.class.new(options, instance, attribute, dir, filename, version.to_s )
        end
      end
    end

    def to_s #:nodoc:
      filename
    end
    
    def size
      File.size(self.path)
    end
    
    def exists?
      File.exists?(self.path)
    end

    # Processes the file with RMagick. This works only if the file is an image that
    # RMagick can understand. The image is loaded using +Image::read+ and then passed
    # to a block, +process+ then returns the result of the block, like so:
    #     new_image = @user.picture.process do |img|
    #       img = img.thumbnail( 0.1 )
    #       img.solarize
    #     end
    # Resulting in an image shrunk to 10% of the original size and solarized. For more information
    # on what you can do inside a +process+ block, see the RMagick doumentation at:
    # http://www.simplesystems.org/RMagick/doc/index.html.
    #
    # Note that you will need to 'carry' the image since most Rmagick methods do not modify
    # the image itself but rather return the result of the transformation.
    #
    # Note also that unlike RMagicks's read, this method will return nil if the image cannot
    # be opened, it will not throw an Error, so you can happily
    # apply this, even if you aren't sure that the file is an image.
    #
    # +process!+ is usually more useful, don't use +process+ unless there is a good reason to!
    #
    # Remember to call GC.start after you are done processing the image, to avoid memory leaks.
    def process
      # Load the file as a ImageMagick object, pass to block, return the yielded result
      begin
        img = ::Magick::Image::read(self.path).first
      rescue Magick::ImageMagickError
        return nil
      end
      yield( img )
    end

    # Like +process+, but instead of returning the new image, it will replace this one.
    # Use +process!+ in an _after_assign callback, like so:
    #     class User < ActiveRecord::Base
    #       upload_column :picture
    #       
    #       def picture_after_assign
    #         picture.process! do |img|
    #           img.solarize
    #         end
    #       end
    # 
    #     end
    # This is an easy way to apply some RMagick effect to an image right after it's uploaded
    #
    # Note that this method will silently fail if the image cannot be opened, so you can happily
    # apply this, even if you aren't sure that the file is an images.
    #
    # To prevent memory leaks, process! will call GC.start manually.
    def process!
      img = process do |img|
        img = yield( img )
      end
      return false if img.nil?
      img.write self.path
      img = nil
      GC.start
      true
    end

    # Returns the absolute path of the file
    def path()
      join_path(self.store_dir, self.filename)
    end

    # Returns the path of the file, relative to store_dir( true )
    # Note: this is not relative to the same directory as relative_dir, I am aware
    # that that makes no sense whatsoever, but until I come up with a better name for one
    # of the methods it'll have to do, suggestions are appreciated :)
    def relative_path()
      join_path(self.dir, self.filename)
    end

    # Returns the URL of the file, you can use this in your views to easily create links to
    # your files:
    #     <%= link_to "#{@song.title} Tab", @song.guitar_tab.url %>
    # Or if your file is an image, you can use +url+ like so:
    #     <%= image_tag @user.picture.url %>
    def url
      options[:web_root] + ( "/" << self.relative_dir.gsub("\\", "/") << "/" << self.filename )
    end

    # Returns the directory where the file is (or will be) permanently stored
    def store_dir( root_dir = false )
      File.expand_path(relative_dir( root_dir ), options[:root_path])
    end

    # Like +store_dir+ but will return the directory relative to the :root_path option
    def relative_dir( root_dir = false )
      # Increase speed by bypassing this code if it's called multiple times
      unless @relative_dir
        model = Inflector.underscore(self.instance.class).to_s
        sd = self.instance.send("#{self.attribute}_store_dir")
        sd ||= options[:store_dir]
        sd ||= join_path(model, self.attribute.to_s)
        @relative_dir = sd
      end
      return join_path( @relative_dir, self.dir ) unless root_dir
      return @relative_dir
    end

    # Returns the filename without the extension
    def filename_base
      split_extension[0]
    end

    # Returns the file's extension
    def filename_extension
      split_extension[1]
    end

    # Guesses the mime-type of the file based on it's extension, returns a String.
    def mime_type
      return @mime_type if @mime_type
      case filename_extension
      when "jpg":
        return "image/jpeg"
      when "gif":
        return "image/gif"
      when "png":
        return "image/png"
      else
        @mime_type = MIME_EXTENSIONS.invert[filename_extension]
      end
    end

    # returns the file's name
    def filename
      if suffix.nil?
        @filename
      else
        "#{filename_base}-#{suffix}.#{filename_extension}"
      end
    end

    private
    
    # Set the filename, use at your own risk!
    def filename=(name)
      @filename = sanitize_filename( name )
    end
    
    # Assigns a file to this upload column and stores it in a temporary file,
    def assign(file, directory = nil )
      unless file.nil?
        if file.size == 0
          return false
        else
          if file.is_a?(String)
            # if file is a non-empty string it is most probably
            # the filename and the user forgot to set the encoding
            # to multipart/form-data. Since we would raise an exception
            # because of the missing "original_filename" method anyways,
            # we raise a more meaningful exception rightaway.
            raise TypeError.new("Do not know how to handle a string with value '#{file}' that was passed to an upload_column. Check if the form's encoding has been set to 'multipart/form-data'.")
          end
      
          if file.original_filename != ""
      
            self.dir = directory || join_path( options[:tmp_dir], generate_temp_name )            
      
            FileUtils.mkpath(self.store_dir)
            
            self.filename = file.original_filename

            # stored uploaded file into self.path
            # If it was a Tempfile object, the temporary file will be
            # cleaned up automatically, so we do not have to care for this
            # Large files will be passed as tempfiles, whereas small ones
            # will be passed as StringIO
            if file.respond_to?(:local_path) and file.local_path and File.exists?(file.local_path)
              mime_type = fix_file_extension( file, file.local_path )
              return false unless check_integrity( self.filename_extension )
              FileUtils.copy_file( file.local_path, self.path )
            elsif file.respond_to?(:read)
              mime_type = fix_file_extension( file, nil )
              return false unless check_integrity( self.filename_extension )
              file.rewind # Make sure we are at the beginning of the buffer
              File.open(self.path, "wb") { |f| f.write(file.read) }
            else
              raise ArgumentError.new("Do not know how to handle #{file.inspect}")
            end
                  
            versions.each { |k, v| v.send(:assign, file, dir) } if versions
            
            return true
          end
        end
      end
    end
    
    def save
      new_dir = if options[:store_dir_append_id] then self.instance.id.to_s else nil end
      new_abs_dir = join_path( self.store_dir(true), new_dir )
      new_path = join_path( new_abs_dir, filename )
  
      # Check if a new file has actually been assigned
      if self.filename and self.filename != "" and new_path != self.path
   
        # create the directory first
        FileUtils.mkpath(new_abs_dir) unless File.exists?(new_abs_dir)

        # move the temporary file over
        FileUtils.cp( self.path, new_path )

        # remove the old file, do this after in case copying fails.      
        #self.delete if options[:replace_old_files]
  
        self.dir = new_dir
    
        versions.each { |k, v| v.send(:save) } if versions
      end
    end
    
    def set_magic_columns(  )
      self.instance.class.column_names.each do |column|
        if column =~ /^#{self.attribute}_(.*)$/
          case $1
          when "mime_type"
            self.instance.send("#{self.attribute}_mime_type=".to_sym, self.mime_type)
          when "filesize"
            self.instance.send("#{self.attribute}_filesize=".to_sym, self.size)
          end
        end
      end
    end
    
    def delete_temporary_files #:nodoc:
      FileUtils.rm_rf( Dir.glob(join_path(store_dir(true), options[:tmp_dir], "*") ) )
    end

    # Delete this file, note that it will only delete the FILE, not the value in the
    # database
    def delete
      if self.dir and self.store_dir
        FileUtils.rm_rf( self.store_dir )
      else
        FileUtils.rm( self.path ) if File.exists?( self.path )
        versions.each { |k, v| v.send(:delete) } if versions
      end
    end
    
    def set_path(temp_path) #:nodoc:
      return if temp_path == self.relative_path # We do not need to set this path
      raise ArgumentError.new("invalid format of '#{temp_path}'") unless temp_path =~ %r{^([^/]+/(\d+\.)+\d+)/([^/].+)$}
      self.dir = $1
      self.filename = $3
      versions.each { |k, v| v.send(:filename=, $3); v.send(:dir=, $1) } if versions
    end
    
    def check_integrity( extension )
      if self.options[:validate_integrity]
        unless self.options[:extensions].include?( extension )
          return false
        end
      end
      true
    end

    def generate_temp_name
      now = Time.now
      "#{now.to_i}.#{now.usec}.#{Process.pid}"
    end

    def join_path( *paths )
      # remove paths that are nil
      paths.delete( nil )
      File.join( paths )
    end

    # Split the filename into base and extension
    def split_extension()
      # regular expressions to try for identifying extensions
      ext_regexps = [ 
        /^(.+)\.([^.]+\.[^.]+)$/, # matches "something.tar.gz"
        /^(.+)\.([^.]+)$/ # matches "something.jpg"
      ]
      ext_regexps.each do |regexp|
        if @filename =~ regexp
          base, ext = $1, $2
          return [base, ext] if options[:extensions].include?(ext.downcase)
        end
      end
      [@filename, ""]
    end

    def sanitize_filename(name)
      # Sanitize the filename, to prevent hacking
      name = File.basename(name.gsub("\\", "/")) # work-around for IE
      name.gsub!(/[^a-zA-Z0-9\.\-\+_]/,"_")
      name = "_#{name}" if name =~ /^\.+$/ # huh? some specific browser fix?
      name = "unnamed" if name.size == 0
      name
    end

    # tries to identify the mime-type of file and correct self's extension
    # based on the found mime-type
    def fix_file_extension( file, local_path )
      # try to fetch the filename via the 'file' Unix exec
      content_type = get_content_type( local_path )
      # Fetch the content type that was passed from the users browser
      content_type ||= file.content_type.chomp if file.content_type
      
      # Is this one of our known content types?
      if content_type and options[:fix_file_extensions] and options[:mime_extensions][content_type]
        # If so, correct the extension
        self.filename = self.filename_base + "." + options[:mime_extensions][content_type]
      end
      
      content_type
    end
    
    # Try to use *nix exec to fetch content type
    def get_content_type( local_path )
      if options[:file_exec] and local_path
        begin
          content_type = `file -bi "#{local_path}"`.chomp
          return nil unless $?.success?
          return nil if content_type =~ /cannot_open/
          # Cut off ;xyz from the result
          content_type.gsub!(/;.+$/,"") if content_type =~ /;.+$/
          return content_type
        rescue
          nil
        end
      end
    end

    # Catch when different versions are requested... e.g. upload_column.thumb
    def method_missing(method_name, *args)
      if versions and versions.include?(method_name)
        return versions[method_name.to_sym]
      end
      raise NoMethodError.new( "Method #{method_name} not found in UploadColumn::UploadedFile")
    end
  end

  # = Basics
  # When you call an +image_column+ field, an instance of this class will be returned.
  #
  # See +image_column+ and the +README+ for more info
  class UploadedImage < UploadedFile
    
    attr_reader :width, :height
    # Resize the image so that it will not exceed the dimensions passed
    # via geometry, geometry should be a string, formatted like '200x100' where
    # the first number is the height and the second is the width
    def resize!( geometry )
      process! do |img|
        img.change_geometry( geometry ) do |c, r, i|
          i.resize(c,r)
        end
      end
    end
    
    # Resize and crop the image so that it will have the exact dimensions passed
    # via geometry, geometry should be a string, formatted like '200x100' where
    # the first number is the height and the second is the width
    def crop_resized!( geometry )
      process! do |img|
        h, w = geometry.split('x')
        img.crop_resized(h.to_i,w.to_i)
      end
    end
    
    private
    
    # I eat your memory for breakfast, don't use me!
    def width
      unless @width
        img = process do |img|
          @width = img.columns
          @height = img.rows
        end
        img = nil
        GC.start
      end
      @width
    end
    
    def height
      unless @height
        img = process do |img|
          @width = img.columns
          @height = img.rows
        end
        img = nil
        GC.start
      end
      @height
    end
    
    def set_magic_columns
      super
      self.instance.class.column_names.each do |column|
        if column =~ /^#{self.attribute}_(.*)$/
          case $1
          when "width"
            self.instance.send("#{self.attribute}_width=".to_sym, width)
          when "height"
            self.instance.send("#{self.attribute}_height=".to_sym, height)
          when /^exif_(.*)$/
            if self.mime_type == "image/jpeg"
              require_gem 'exifr'
              i = EXIFR::JPEG.new(self.path)
              self.instance.send("#{self.attribute}_exif_#{$1}=".to_sym, i.exif[$1.to_sym]) if i and i.exif
            end
          end
        end
      end
      
    end
    
    def assign(file, directory = nil )
      # Call superclass method and check for success (not if this actually IS a version!)
      if super(file, directory) and suffix.nil? and options[:versions].is_a?( Hash )
        
        options[:versions].each do |name, size|
          # Check if size is a string, and if so resize the respective version
          if size.is_a?( String )
            if options[:crop]
              return false unless self.versions[name].crop_resized!( size )
            else
              return false unless self.versions[name].resize!( size )
            end
          else
            raise TypeError.new( "#{size.inspect} is not a valid option, must be of format '123x123'")
          end
        end
        
      end
      true
    end
  end

  module ClassMethods

    # handle the +attr+ attribute as an "upload-column" field, generating additional methods as explained
    # in the README. You should pass the attribute's name as a symbol, like this:
    #
    #   upload_column :picture
    #
    # +upload_column+ accepts the following common options:
    # [+versions+] Creates different versions of the file, must be an Array, +image_column+ allows a Hash of dimensions to be passed.
    # [+store_dir+] Overwrite the default mechanism for deciding where the files are stored
    # [+old_files+] Determines what happens when a file becomes outdated. It can be set to one of <tt>:accumulate</tt>, <tt>:keep</tt>, <tt>:delete</tt> and <tt>:replace</tt>. If set to <tt>:keep</tt> UploadColumn will always keep old files, and if set to :delete it will always delete them. If it's set to :replace, the file will be replaced when a new one is uploaded, but will be kept when the associated object is deleted. If it's set to :accumulate, which is the default option, then all new files will be kept, but the files will be deleted when the associated object is destroyed.
    # 
    # and even the following less common ones
    # [+root_path+] The root path where image will be stored, it will be prepended to store_dir
    # [+web_root+] Prepended to all addresses returned by UploadColumn::BaseUploadedFile.url
    # [+mime_extensions+] Overwrite UploadColumns default list of mime-type to extension mappings
    # [+extensions+] Overwirte UploadColumns default list of extensions that may be uploaded
    # [+fix_file_extensions+] Try to fix the file's extension based on its mime-type, note that this does not give you any security, to make sure that no dangerous files are uploaded, set :validate_integrity to true (it is by default). Defaults to true
    # [+store_dir_append_id+] Append a directory labeled with the records ID to the path where the file is stored, defaults to true
    # [+tmp_base_dir+] The base directory where the image temp files are stored, defaults to "tmp"
    # [+validate_integrity] If set to true, no files with an extension not included in :extensions will be uploaded, defaults to true.
    # [+file_exec+] Path to an executable used to find out a files mime_type, works only on *nix based systems. Defaults to 'file'
    def upload_column(attr, options={})
      register_functions( attr, UploadedFile, options )
    end
    
    # Creates a column specifically designed for images, see +upload_column+ for options
    # Additinally yuu may specify:
    # [+crop+] Specifies whether the image will be cropped to fit the dimensions passed via versions, that way the image will always be exactly the specified size (otherwise that size would be a maximum), however some areas of the image may be cut off. Default to false.
    def image_column( attr, options={} )
      options[:crop] ||= false
      options[:web_root] ||= "/images"
      options[:root_path] ||= File.join(RAILS_ROOT, "public", "images")
      options[:mime_extensions] ||= IMAGE_MIME_EXTENSIONS
      options[:extensions] ||= IMAGE_EXTENSIONS
      
      register_functions( attr, UploadedImage, options )
    end
    
    # Validates whether the images extension is in the array passed to :extensions.
    # By default this is the UploadColumn::EXTENSIONS array
    # 
    # Use this to prevent upload of files which could potentially damage your system,
    # such as executables or script files (.rb, .php, etc...). ALWAYS use this method
    # if a source you can't trust completely can upload files!
    def validates_integrity_of(*attr_names)
      configuration = { :message => "is not of a valid file type." }
      configuration.update(attr_names.pop) if attr_names.last.is_a?(Hash)
     
      validates_each(attr_names, configuration) do |record, attr, column|
        if column and not column.options[:extensions].include?( column.filename_extension )
          record.errors.add(attr, configuration[:message])
        end
      end
    end
    
    private
    
    def register_functions(attr, column_class, options={})
      upload_column_attr = "@#{attr}_file".to_sym
      upload_column_method = "#{attr}".to_sym
  
      define_method upload_column_method do
        result = instance_variable_get( upload_column_attr )
        if result.nil?
          filename = self[attr]
          if filename.nil? or filename.empty?
            nil
          else
            result = column_class.new(options, self, attr)
          end
          instance_variable_set upload_column_attr, result
        end
        result
      end

      define_method "#{attr}=" do |file|
        if file.nil?
          self[attr] = nil
          instance_variable_set upload_column_attr, nil
        else
          uploaded_file = instance_variable_get( upload_column_attr )
          old_file = uploaded_file.dup if uploaded_file
          uploaded_file ||= column_class.new(options, self, attr)
          # We simply write over the temp version if it exists
          if file and not file.blank? and uploaded_file.send(:assign, file)
            instance_variable_set upload_column_attr, uploaded_file
            self.send("#{attr}_after_assign")
            self[attr] = uploaded_file.to_s
            uploaded_file.send(:set_magic_columns)
            if old_file and [ :replace, :delete ].include?(options[:old_files])
              old_file.send(:delete)
            end
          else
            # Reset if something's gone wrong
            instance_variable_set upload_column_attr, old_file
          end
        end
      end
  
      define_method "#{attr}_temp" do
        uploaded_file = send(upload_column_method)
        return uploaded_file.relative_path if uploaded_file
        ""
      end
  
      define_method "#{attr}_temp=" do |temp_path|
        if temp_path and temp_path != ""
          uploaded_file = instance_variable_get( upload_column_attr )
          # The actual upload should always have preference over the temp upload
          unless uploaded_file
            uploaded_file = column_class.new(options, self, attr)
            uploaded_file.send(:set_path, temp_path)
            instance_variable_set upload_column_attr, uploaded_file
            self[attr] = uploaded_file.to_s
          end
        end
      end

      # Callbacks the user can use to hook into uploadcolumn
      define_method "#{attr}_store_dir" do
      end
      
      define_method "#{attr}_after_assign" do
      end

      # Hook UploadColumn into Rails via after_save and after_destroy
      after_save_method = "#{attr}_after_save".to_sym
  
      define_method after_save_method do
        uploaded_file = send(upload_column_method)
        if uploaded_file
          uploaded_file.send(:save)
          uploaded_file.send(:delete_temporary_files)
        end
      end
  
      after_save after_save_method
  
      # After destroy
      after_destroy_method = "#{attr}_after_destroy".to_sym
  
      define_method after_destroy_method do
        uploaded_file = send(upload_column_method)
        uploaded_file.send(:delete) if uploaded_file and not [ :keep, :replace ].include?(options[:old_files])
      end
      after_destroy after_destroy_method
  
      private after_save_method, after_destroy_method
      
      
    end

  end



end
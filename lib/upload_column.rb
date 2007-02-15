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

  # default options. You can override these with +upload_column+'s +options+ parameter
  DEFAULT_OPTIONS = {
    :root_path => File.join(RAILS_ROOT, "public"),
    :web_root => "",
    :mime_extensions => MIME_EXTENSIONS,
    :extensions => EXTENSIONS,
    :fix_file_extensions => true,
    :store_dir => proc{|inst, attr| File.join(Inflector.underscore(inst.class).to_s, attr.to_s, inst.id.to_s) },
    :tmp_dir => proc{|inst, attr| File.join(Inflector.underscore(inst.class).to_s, attr.to_s, "tmp") },
    :old_files => :delete,
    :validate_integrity => true,
    :file_exec => 'file',
    :filename => proc{|inst, original, ext| original + ( ext.blank? ? '' : ".#{ext}" )},
    :permissions => 0644
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

    attr_accessor :options, :mime_type, :ext, :original_basename
    attr_reader :instance, :attribute, :versions, :suffix, :options, :relative_dir

    private :mime_type=, :ext=, :original_basename=

    def initialize(options, instance, attribute, dir = nil, filename = nil, suffix = nil)
      options = DEFAULT_OPTIONS.merge(options)
  
      @options = options
      @instance = instance
      @attribute = attribute
      @filename = filename || instance[attribute]
      @suffix = suffix
      
      @relative_dir = dir
      @relative_dir ||= self.relative_store_dir 
      
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
    
    # Returns the file's size
    def size
      File.size(self.path)
    end
    
    # checks whether the file exists
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
    
    # Returns the (absolute) directory where the file is currently stored.
    def dir
      File.expand_path(self.relative_dir, options[:root_path])
    end

    # Returns the (absolute) path of the file
    def path
      File.expand_path(self.relative_path, options[:root_path])
    end

    # Returns the path of the file relative to :root_path
    def relative_path()
      join_path(self.relative_dir, self.filename)
    end

    # Returns the URL of the file, you can use this in your views to easily create links to
    # your files:
    #     <%= link_to "#{@song.title} Tab", @song.guitar_tab.url %>
    # Or if your file is an image, you can use +url+ like so:
    #     <%= image_tag @user.picture.url %>
    def url
      options[:web_root] + ( "/" << self.relative_path.gsub("\\", "/") )
    end

    # Returns the directory where the file is (or will be) permanently stored
    def store_dir
      File.expand_path(self.relative_store_dir, options[:root_path])
    end
    
    # Like +store_dir+ but will return the directory relative to the :root_path option
    def relative_store_dir
      sd = self.instance.send("#{self.attribute}_store_dir")
      if options[:store_dir].is_a?( Proc )
        sd ||= options[:store_dir].call(self.instance, self.attribute)
      else
        sd ||= options[:store_dir]
      end
      return sd
    end
    
    # Returns the directory where the file will be temporarily stored between form redisplays
    def tmp_dir
      File.expand_path(self.relative_tmp_dir, options[:root_path])
    end
    
    # Like +tmp_dir+ but will return the directory relative to the :root_path option
    def relative_tmp_dir
      sd = self.instance.send("#{self.attribute}_tmp_dir")
      if options[:tmp_dir].is_a?( Proc )
        sd ||= options[:tmp_dir].call(self.instance, self.attribute)
      else
        sd ||= options[:tmp_dir]
      end
      return sd
    end

    # Returns the filename without the extension
    def filename_base
      split_extension(@filename)[0]
    end

    # Returns the file's extension
    def filename_extension
      split_extension(@filename)[1]
    end

    # Returns the mime-type of the file.
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
      expand_filename(@filename)
    end

    private
    
    # Set the filename, use at your own risk!
    def filename=(name)
      @filename = sanitize_filename( name )
    end
    
    def relative_dir=(dir)
      @relative_dir = dir
    end
    
    # Assigns a file to this upload column and stores it in a temporary file,
    # Note: does not check the validity of the file!
    def assign(file, directory = nil )
            
      unless directory
        directory = join_path( self.relative_tmp_dir, generate_temp_name )
      end
      
      #
      #self.filename = fetch_filename( self.instance, basename, ext )
      self.relative_dir = directory
      
      FileUtils.mkpath(self.dir)
      
      # stored uploaded file into self.path
      # If it was a Tempfile object, the temporary file will be
      # cleaned up automatically, so we do not have to care for this
      # Large files will be passed as tempfiles, whereas small ones
      # will be passed as StringIO
      if temp_path = ( file.respond_to?(:local_path) ? file.local_path : file.path ) and temp_path != "" 
        if File.exists?(temp_path)
          temp_filename = file.original_filename if file.respond_to?(:original_filename)
          temp_filename ||= File.basename(file.path)
          basename, self.ext = split_extension(temp_filename)
          self.ext, self.mime_type = fetch_file_extension( file, temp_path, self.ext )
          self.filename = fetch_filename( self.instance, basename, self.ext )
          return false unless check_integrity( self.filename_extension )
          FileUtils.copy_file( temp_path, self.path )
        else
          raise ArgumentError.new("File #{file.inspect} at #{temp_path.inspect} does not exist")
        end
      elsif file.respond_to?(:read)
        basename, self.ext = split_extension(file.original_filename)
        self.ext, self.mime_type = fetch_file_extension( file, nil, self.ext )
        self.filename = fetch_filename( self.instance, basename, self.ext )
        return false unless check_integrity( self.filename_extension )
        file.rewind # Make sure we are at the beginning of the buffer
        File.open(self.path, "wb") { |f| f.write(file.read) }
      else
        raise ArgumentError.new("Do not know how to handle #{file.inspect}")
      end
      
      self.original_basename = basename
 
      versions.each { |k, v| v.send(:assign_version, self.path, self.relative_dir, self.filename, self.original_basename, self.ext) } if versions
      
      File.chmod(options[:permissions], self.path)
      
      set_magic_columns
      
      return true
    end
    
    def assign_version( path, directory, filename, basename, ext )
      self.relative_dir = directory
      self.filename = filename
      self.ext = ext
      self.original_basename = basename
      FileUtils.copy_file( path, self.path )
    end
    
    def save
        
      new_dir = self.store_dir
      new_filename = sanitize_filename(fetch_filename(self.instance, self.original_basename, self.ext))
      new_path = join_path( new_dir, expand_filename(new_filename) )
      
      # create the directory first
      FileUtils.mkpath(new_dir) #unless File.exists?(new_di)

      # move the temporary file over
      FileUtils.cp( self.path, new_path )

      self.relative_dir = self.relative_store_dir
      self.filename = new_filename

      versions.each { |k, v| v.send(:save) } if versions
    end
    
    def fetch_filename(inst, original, ext)
      fn = self.instance.send("#{self.attribute}_filename", original, ext)
      if options[:filename].is_a?( Proc )
        fn ||= options[:filename].call(inst, original, ext)
      else
        fn ||= options[:filename]
      end
      fn
    end
    
    def set_magic_columns
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
    
    def delete_temporary_files
      Dir.glob(join_path(self.tmp_dir, "*")).each do |file|
        # Check if the file was created more than an hour ago
        if file =~ %r{(\d+)\.[\d]+\.[\d]+$} and $1.to_i < ( Time.now - 3600 ).to_i
          FileUtils.rm_rf(file)
        end
      end
    end

    # Delete this file, note that it will only delete the FILE, not the value in the
    # database
    def delete
      FileUtils.rm( self.path ) if File.exists?( self.path )
      versions.each { |k, v| v.send(:delete) } if versions
      if Dir.glob(join_path(self.dir, '*')).empty?
        FileUtils.rm_rf( self.dir )
      end
    end
    
    def set_path(temp_path)
      return if temp_path == self.relative_path # We do not need to set this path
      raise ArgumentError.new("invalid format of '#{temp_path}'") unless temp_path =~ %r{^((\d+\.)+\d+)/([^/;]+)(;([^/;]+))?$}
      self.relative_dir = join_path( self.relative_tmp_dir, $1 )
      self.original_basename, self.ext = split_extension($5 || $3)
      self.filename = $3
      if versions
        versions.each do |k, v|
          v.send(:filename=, self.filename)
          v.send(:relative_dir=, self.relative_dir)
          v.send(:original_basename=, self.original_basename)
          v.send(:ext=, self.ext)
        end
      end
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
    def split_extension(fn)
      # regular expressions to try for identifying extensions
      ext_regexps = [ 
        /^(.+)\.([^.]+\.[^.]+)$/, # matches "something.tar.gz"
        /^(.+)\.([^.]+)$/ # matches "something.jpg"
      ]
      ext_regexps.each do |regexp|
        if fn =~ regexp
          base, ext = $1, $2
          return [base, ext] if options[:extensions].include?(ext.downcase)
        end
      end
      [fn, ""]
    end

    def sanitize_filename(name)
      # Sanitize the filename, to prevent hacking
      name = File.basename(name.gsub("\\", "/")) # work-around for IE
      name.gsub!(/[^a-zA-Z0-9\.\-\+_]/,"_")
      name = "_#{name}" if name =~ /^\.+$/ # huh? some specific browser fix?
      name = "unnamed" if name.size == 0
      name
    end
    
    def expand_filename(fn)
      if suffix.nil?
        fn
      else
        base, ext = split_extension(fn)
        "#{base}-#{self.suffix}.#{ext}"
      end
    end

    # tries to identify the mime-type of file and correct self's extension
    # based on the found mime-type
    def fetch_file_extension( file, local_path, ext )
      # try to fetch the filename via the 'file' Unix exec
      content_type = get_content_type( local_path )
      # Fetch the content type that was passed from the users browser
      content_type ||= file.content_type.chomp if file.respond_to?(:content_type) and file.content_type
      
      # Is this one of our known content types?
      if content_type and options[:fix_file_extensions] and options[:mime_extensions][content_type]
        # If so, correct the extension
        return options[:mime_extensions][content_type], content_type
      else
        return ext, content_type
      end
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
    
    # Convert the image to format
    def convert!(format)
      process! do |img|
        img.format = format.to_s.upcase
        img
      end
    end
    
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
      if super(file, directory)
        
        if options[:force_format] and options[:extensions].include?(options[:force_format].to_s)
          convert!(options[:force_format])
          @mime_type = options[:mime_extensions][options[:force_format]]
          self.instance.send("#{self.attribute}_mime_type=".to_sym, self.mime_type) if self.instance.class.column_names.include?("#{self.attribute}_mime_type")
          self.versions.each { |k, v| v.send(:convert!, options[:force_format]) } if self.versions
        end
        if suffix.nil? and options[:versions].respond_to?( :to_hash )
        
          options[:versions].to_hash.each do |name, size|
            # Check if size is a string, and if so resize the respective version
            if size.is_a?( String )
              if options[:crop]
                return false unless self.versions[name].crop_resized!( size )
              elsif size[0,1] == "c"
                return false unless self.versions[name].crop_resized!( size[1,30] )
              else
                return false unless self.versions[name].resize!( size )
              end
            elsif size.is_a?( Proc )
              self.versions[name].process! do |img|
                img = size.call(img)
              end
            elsif size != :none
              raise TypeError.new( "#{size.inspect} is not a valid option, must be of format '123x123' or a Proc or :none.")
            end
          end
        end
        return true
      else
        return false
      end
    end
    
    def fetch_file_extension( file, local_path, ext )
      ext, content_type = super(file, local_path, ext)
      ext = options[:force_format].to_s if options[:force_format] and options[:extensions].include?(options[:force_format].to_s)
      return ext, content_type
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
    # [+store_dir+] Determines where the file will be stored permanently, you can pass a String or a Proc that takes the current instance and the attribute name as parameters, see the +README+ for detaills.
    # [+tmp_dir+] Determines where the file will be stored temporarily before it is stored to its final location, you can pass a String or a Proc that takes the current instance and the attribute name as parameters, see the +README+ for detaills.
    # [+old_files+] Determines what happens when a file becomes outdated. It can be set to one of <tt>:keep</tt>, <tt>:delete</tt> and <tt>:replace</tt>. If set to <tt>:keep</tt> UploadColumn will always keep old files, and if set to :delete it will always delete them. If it's set to :replace, the file will be replaced when a new one is uploaded, but will be kept when the associated object is deleted. Default to :delete.
    # 
    # and even the following less common ones
    # [+permissions+] Specify the Unix permissions to be used with UploadColumn. Defaults to 0644.
    # [+root_path+] The root path where image will be stored, it will be prepended to store_dir and tmp_dir
    # [+web_root+] Prepended to all addresses returned by UploadColumn::BaseUploadedFile.url
    # [+mime_extensions+] Overwrite UploadColumns default list of mime-type to extension mappings
    # [+extensions+] Overwirte UploadColumns default list of extensions that may be uploaded
    # [+fix_file_extensions+] Try to fix the file's extension based on its mime-type, note that this does not give you any security, to make sure that no dangerous files are uploaded, set :validate_integrity to true (it is by default). Defaults to true
    # [+validate_integrity] If set to true, no files with an extension not included in :extensions will be uploaded, defaults to true.
    # [+file_exec+] Path to an executable used to find out a files mime_type, works only on *nix based systems. Defaults to 'file'
    def upload_column(attr, options={})
      register_functions( attr, UploadedFile, options )
    end
    
    # Creates a column specifically designed for images, see +upload_column+ for options
    # Additinally you may specify:
    # [+crop+] Specifies whether the image will be cropped to fit the dimensions passed
    # via versions, that way the image will always be exactly the specified size (otherwise
    # that size would be a maximum), however some areas of the image may be cut off. Default to false.
    # [+force_format+] Allows you to specify an image format, all images will automatically be converter to that format. (Defaults to false)
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
    # such as executables or script files (.rb, .php, etc...).
    #
    # WARNING: validates_integrity_of does NOT work with :validates_integrity => true (which is the default)!
    # 
    # EVEN STRONGER WARNING: Even if you use validates_integrity_of, potentially harmful files may still be uploaded to your
    # tmp dir, make sure that these are not in your public directory, otherwise a hacker might seriously damage
    # your system (by uploading .rb files or similar), if you want to avoid this problem, use :validate_integrity => true instead!
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
          
          
          if file and not file.blank? and file.is_a?(String)
            # if file is a non-empty string it is most probably
            # the filename and the user forgot to set the encoding
            # to multipart/form-data. Since we would raise an exception
            # because of the missing "original_filename" method anyways,
            # we raise a more meaningful exception rightaway.
            raise TypeError.new("Do not know how to handle a string with value '#{file}' that was passed to an upload_column. Check if the form's encoding has been set to 'multipart/form-data'.")
          end
                   
          filesize = file.size if file.respond_to?(:size)
          filesize = file.stat.size if not file and file.respond_to?(:stat)
          if file and not file.blank? and filesize != 0 and uploaded_file.send(:assign, file)
            instance_variable_set upload_column_attr, uploaded_file
            self.send("#{attr}_after_assign")
            self[attr] = uploaded_file.to_s
            #uploaded_file.send(:set_magic_columns)
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
        # Return the real path and the original(!) filename, we need that to fetch the filename later ;)
        if uploaded_file and uploaded_file.original_basename
          return uploaded_file.relative_path.sub( "#{uploaded_file.relative_tmp_dir}/", '' ) + ";#{uploaded_file.original_basename}.#{uploaded_file.ext}"
        elsif uploaded_file
          return uploaded_file.relative_path.sub( "#{uploaded_file.relative_tmp_dir}/", '' )
        else
          return ""
        end
      end
  
      define_method "#{attr}_temp=" do |temp_path|
        if temp_path and temp_path != ""
          uploaded_file = instance_variable_get( upload_column_attr )
          # The actual upload should always have preference over the temp upload
          unless uploaded_file
            uploaded_file = column_class.new(options, self, attr)
            uploaded_file.send(:set_path, temp_path)
            uploaded_file.send(:set_magic_columns)
            instance_variable_set upload_column_attr, uploaded_file
            self[attr] = uploaded_file.to_s
          end
        end
      end

      # Callbacks the user can use to hook into uploadcolumn
      define_method "#{attr}_filename" do |original, ext|
      end
      
      define_method "#{attr}_store_dir" do
      end
      
      define_method "#{attr}_tmp_dir" do
      end
      
      define_method "#{attr}_after_assign" do
      end

      # Hook UploadColumn into Rails via before_save, after_save and after_destroy
      after_save_method = "#{attr}_after_save".to_sym
  
      define_method after_save_method do
        uploaded_file = send(upload_column_method)
        # Check if the filename is blank, is this a tmp file?
        if uploaded_file and uploaded_file.filename and not uploaded_file.filename.blank? and uploaded_file.dir != uploaded_file.store_dir
          old_dir = uploaded_file.dir
          uploaded_file.send(:save)
          uploaded_file.send(:delete_temporary_files)
          connection.update(
            "UPDATE #{self.class.table_name} " +
            "SET #{quoted_comma_pair_list(connection, {attr => quote_value(uploaded_file.to_s)})} " +
            "WHERE #{self.class.primary_key} = #{quote_value(self.id)}",
            "#{self.class.name} Update"
          )
          FileUtils.rm_rf(old_dir)
        end
      end
  
      after_save after_save_method
      
#      before_save_method = "#{attr}_before_save".to_sym
#  
#      define_method before_save_method do
#        uploaded_file = send(upload_column_method)
#        if uploaded_file and uploaded_file.dir != uploaded_file.store_dir
#          uploaded_file.send(:filename=, uploaded_file.send(:fetch_filename, self, uploaded_file.send(:original_basename), uploaded_file.send(:ext)))
#        end
#      end
  
#      before_save before_save_method
  
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
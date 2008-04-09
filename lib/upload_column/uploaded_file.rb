module UploadColumn
  
  class UploadError < StandardError #:nodoc:
  end 
  class IntegrityError < UploadError #:nodoc:
  end 
  class TemporaryPathMalformedError < UploadError #:nodoc:
  end
  class UploadNotMultipartError < UploadError #:nodoc:
  end
  
  TempValueRegexp = %r{^((?:\d+\.)+\d+)/([^/;]+)(?:;([^/;]+))?$}
  

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
  # See the +README+ for more detaills.
  class UploadedFile < SanitizedFile
    
    attr_reader :instance, :attribute, :options, :versions
    attr_accessor :suffix
    
    class << self
      
      # upload a file. In most cases you want to pass the ActiveRecord instance and the attribute
      # name as well as the file. For a more bare-bones approach, check out SanitizedFile.
      def upload(file, instance = nil, attribute = nil, options = {}) #:nodoc:
        uf = self.new(:upload, file, instance, attribute, options)
        return uf.empty? ? nil : uf
      end

      # Retrieve a file from the filesystem, based on the calculated store_dir and the filename
      # stored in the database.
      def retrieve(filename, instance = nil, attribute = nil, options = {}) #:nodoc:
        self.new(:retrieve, filename, instance, attribute, options)
      end

      # Retreieve a file that was stored as a temp file
      def retrieve_temp(path, instance = nil, attribute = nil, options = {}) #:nodoc:
        self.new(:retrieve_temp, path, instance, attribute, options)        
      end
      
    end
    
    def initialize(mode, file, instance, attribute, options={})
      # TODO: the options are always reverse merged in here, in case UploadedFile has
      # been initialized outside UploadColumn proper, this is not a very elegant solution, imho.
      @options = options.reverse_merge(UploadColumn.configuration)
      @instance = instance
      @attribute = attribute
      @suffix = options[:suffix]
      
      load_manipulator
      
      case mode
      when :upload
        if file and file.is_a?(String) and not file.empty?
          raise UploadNotMultipartError.new("Do not know how to handle a string with value '#{file}' that was uploaded. Check if the form's encoding has been set to 'multipart/form-data'.")
        end
        
        super(file, @options)
        
        unless empty?
          if options[:validate_integrity] 
            raise UploadError.new("No list of valid extensions supplied.") unless options[:extensions]
            raise IntegrityError.new("has an extension that is not allowed.") unless options[:extensions].include?(extension)
          end

          @temp_name = generate_tmpname
          @new_file = true
          
          move_to_directory(File.join(tmp_dir, @temp_name))
          
          # The original is processed before versions are initialized.
          self.process!(@options[:process]) if @options[:process] and self.respond_to?(:process!)
          
          initialize_versions do |version|
            copy_to_version(version)
          end
          
          apply_manipulations_to_versions
          
          # trigger the _after_upload callback
          self.instance.send("#{self.attribute}_after_upload", self) if self.instance.respond_to?("#{self.attribute}_after_upload")
        end
      when :retrieve
        @path = File.join(store_dir, file)
        @basename, @extension = split_extension(file)
        initialize_versions
      when :retrieve_temp
        if file and not file.empty?
          @temp_name, name, original_filename = file.scan( ::UploadColumn::TempValueRegexp ).first

          if @temp_name and name
            @path = File.join(tmp_dir, @temp_name, name)
            @basename, @extension = split_extension(name)
            @original_filename = original_filename
            initialize_versions
          else
            raise TemporaryPathMalformedError.new("#{file} is not a valid temporary path!")
          end
        end
      else
        super(file, @options)
        initialize_versions
      end
    end
    
    # Returns the directory where tmp files are stored for this UploadedFile, relative to :root_dir
    def relative_tmp_dir
      parse_dir_options(:tmp_dir)
    end
    
    # Returns the directory where tmp files are stored for this UploadedFile
    def tmp_dir
      File.expand_path(self.relative_tmp_dir, @options[:root_dir])
    end
    
    # Returns the directory where files are stored for this UploadedFile, relative to :root_dir
    def relative_store_dir
      parse_dir_options(:store_dir)
    end
    
    # Returns the directory where files are stored for this UploadedFile
    def store_dir
      File.expand_path(self.relative_store_dir, @options[:root_dir])
    end
    
    # Returns the path of the file relative to :root_dir
    def relative_path
      self.path.sub(File.expand_path(options[:root_dir]) + '/', '')
    end
    
    # returns the full path of the file.
    def path; super; end
    
    # returns the directory where the file is currently stored.
    def dir
      File.dirname(self.path)
    end
  
    # return true if the file has just been uploaded.
    def new_file?
      @new_file
    end
    
    # returns the url of the file, by merging the relative path with the web_root option.
    def public_path
      # TODO: this might present an attack vector if the file is outside the web_root
      options[:web_root].to_s + '/' + self.relative_path.gsub("\\", "/")
    end
    
    alias_method :to_s, :public_path
    alias_method :url, :public_path
    
    # this is the value returned when avatar_temp is called, where avatar is an upload_column 
    def temp_value #:nodoc:
      if tempfile?
        if original_filename
          %(#{@temp_name}/#{filename};#{original_filename})
        else
          %(#{@temp_name}/#{filename})
        end
      end
    end
    
    def inspect #:nodoc:
      "<UploadedFile: #{self.path}>"
    end
    
    def tempfile?
      @temp_name
    end
    
    alias_method :actual_filename, :filename
    
    def filename
      unless bn = parse_dir_options(:filename)
        bn = [self.basename, self.suffix].compact.join('-')
        bn += ".#{self.extension}" unless self.extension.blank?
      end
      return bn
    end
    
    # TODO: this is a public method, should be specced
    def move_to_directory(dir)
      p = File.join(dir, self.filename)
      if copy_file(p)
        @path = p
      end
    end
    
    private
    
    def copy_to_version(version)
      copy = self.clone
      copy.suffix = version
      
      if copy_file(File.join(self.dir, copy.filename))
        return copy
      end
    end
    
    def initialize_versions
      if self.options[:versions]
        @versions = {}
        
        version_keys = options[:versions].is_a?(Hash) ? options[:versions].keys : options[:versions]
        
        version_keys.each do |version|
          
          version = version.to_sym
          
          # Raise an error if the version name is a method on this class
          raise ArgumentError.new("#{version} is an illegal name for an UploadColumn version.") if self.respond_to?(version)
          
          if block_given?
            @versions[version] = yield(version)
          else
            # Copy the file and store it in the versions array
            # TODO: this might result in the manipulator not being loaded.
            @versions[version] = self.clone #class.new(:open, File.join(self.dir, "#{self.basename}-#{version}.#{self.extension}"), instance, attribute, options.merge(:versions => nil, :suffix => version))
            @versions[version].suffix = version
          end
          
          @versions[version].instance_eval { @path = File.join(self.dir, self.filename) } # ensure path is not cached

          # Add the version methods to the instance
          self.instance_eval <<-SRC
            def #{version}
              self.versions[:#{version}]
            end
          SRC
        end
      end
    end
    
    def load_manipulator
      if options[:manipulator]
        self.extend(options[:manipulator])
        self.load_manipulator_dependencies if self.respond_to?(:load_manipulator_dependencies)
      end
    end
    
    def apply_manipulations_to_versions
      @versions.each do |k, v|
        v.process! @options[:versions][k]
      end if @options[:versions].is_a?(Hash)
    end
    
    def save
      self.move_to_directory(self.store_dir)
      self.versions.each { |version, file| file.move_to_directory(self.store_dir) } if self.versions
      @new_file = false
      @temp_name = nil
      true
    end
    
    def parse_dir_options(option)
      if self.instance.respond_to?("#{self.attribute}_#{option}")
        self.instance.send("#{self.attribute}_#{option}", self)
      else
        option = @options[option]
        if option.is_a?(Proc)
          case option.arity
          when 2
            option.call(self.instance, self)
          when 1
            option.call(self.instance)
          else
            option.call
          end
        else
          option
        end
      end
    end
    
    def generate_tmpname
      now = Time.now
      "#{now.to_i}.#{now.usec}.#{Process.pid}"
    end
    
  end
end
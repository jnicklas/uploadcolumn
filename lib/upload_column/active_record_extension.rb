require 'fileutils'
require 'tempfile'
    
module UploadColumn
  
  Column = Struct.new(:name, :options)
  
  module ActiveRecordExtension
  
    def self.append_features(base) #:nodoc:
      super
      base.extend(ClassMethods)
      base.after_save :save_uploaded_files
    end
  
    private
  
    def save_uploaded_files
      @files.each { |k, v| v.send(:save) if v and v.tempfile? } if @files
    end
  
    def get_upload_column(name)
      options = options_for_column(name) #TODO: Spec this!
      @files ||= {}
      return nil if @files[name].is_a?(UploadColumn::IntegrityError)
      @files[name] ||= if self[name] then UploadColumn::UploadedFile.retrieve(self[name], self, name, options) else nil end
    end
  
    def set_upload_column(name, file)
      options = options_for_column(name)
      @files ||= {}
      if file.nil?
        @files[name], self[name] = nil
      else
        begin
          if uploaded_file = UploadColumn::UploadedFile.upload(file, self, name, options)
            self[name] = uploaded_file.actual_filename
            @files[name] = uploaded_file
          end
        rescue IntegrityError => e
          @files[name] = e
        end
      end
    end
  
    def get_upload_column_temp(name)
      @files[name].temp_value if @files and @files[name].respond_to?(:temp_value)
    end
  
    def set_upload_column_temp(name, path)
      options = options_for_column(name)
      @files ||= {}
      return if path.nil? or path.empty?
      unless @files[name] and @files[name].new_file?
        @files[name] = UploadColumn::UploadedFile.retrieve_temp(path, self, name, options)
        self[name] = @files[name].actual_filename
      end
    end
  
    def options_for_column(name)
      return self.class.reflect_on_upload_columns[name].options.reverse_merge(UploadColumn.configuration)
    end
  
    # weave in the magic column methods
    include UploadColumn::MagicColumns

    module ClassMethods
    
      # handle the +attr+ attribute as an "upload-column" field, generating additional methods as explained
      # in the README. You should pass the attribute's name as a symbol, like this:
      #
      #   upload_column :picture
      #
      # +upload_column+ can manipulate file with the following options:
      # [+versions+] Creates different versions of the file, can be an Array or a Hash, in the latter case the values of the Hash will be passed to the manipulator
      # [+manipulator+] Takes a module that must have a method called process! that takes a single argument. Use this in conjucntion with :versions and :process
      # [+process+] This instrucion is passed to the manipulators process! method.
      #
      # you can customize file storage with the following:
      # [+store_dir+] Determines where the file will be stored permanently, you can pass a String or a Proc that takes the current instance and the attribute name as parameters, see the +README+ for detaills.
      # [+tmp_dir+] Determines where the file will be stored temporarily before it is stored to its final location, you can pass a String or a Proc that takes the current instance and the attribute name as parameters, see the +README+ for detaills.
      # [+old_files+] Determines what happens when a file becomes outdated. It can be set to one of <tt>:keep</tt>, <tt>:delete</tt> and <tt>:replace</tt>. If set to <tt>:keep</tt> UploadColumn will always keep old files, and if set to :delete it will always delete them. If it's set to :replace, the file will be replaced when a new one is uploaded, but will be kept when the associated object is deleted. Default to :delete.
      # [+permissions+] Specify the Unix permissions to be used with UploadColumn. Defaults to 0644. Remember that permissions are usually counted in octal and that in Ruby octal numbers start with a zero, so 0644 != 644.
      # [+root_dir+] The root path where image will be stored, it will be prepended to store_dir and tmp_dir
      # 
      # it also accepts the following, less common options:
      # [+web_root+] Prepended to all addresses returned by UploadColumn::UploadedFile.url
      # [+extensions+] A white list of files that can be used together with validates_integrity_of to secure your uploads against malicious files.
      # [+fix_file_extensions+] Try to fix the file's extension based on its mime-type, note that this does not give you any security, to make sure that no dangerous files are uploaded, use +validates_integrity_of+. This defaults to true.
      # [+get_content_type_from_file_exec+] If this is set to true, UploadColumn::SanitizedFile will use a *nix exec to try to figure out the content type of the uploaded file.
      def upload_column(name, options = {})
        @upload_columns ||= {}
        @upload_columns[name] = Column.new(name, options)
      
        define_method( name ) { get_upload_column(name) }
        define_method( "#{name}=" ) { |file| set_upload_column(name, file) }
        
        define_submethod( name, "temp" ) { get_upload_column_temp(name) }      
        define_submethod( name, "temp=" ) { |path| set_upload_column_temp(name, path) }

        define_submethod( name, "public_path" ) { get_upload_column(name).public_path rescue nil }
        define_submethod( name, "path" ) { get_upload_column(name).path rescue nil }
      
        if options[:versions]
          options[:versions].each do |k, v|
            define_submethod( name, k ) { get_upload_column(name).send(k) rescue nil }
            define_submethod( name, k, "public_path" ) { get_upload_column(name).send(k).public_path rescue nil }
            define_submethod( name, k, "path" ) { get_upload_column(name).send(k).path rescue nil }
          end
        end
      end
    
      def image_column(name, options={})
        upload_column(name, options.reverse_merge(UploadColumn.image_column_configuration))
      end
    
      # Validates whether the images extension is in the array passed to :extensions.
      # By default this is the UploadColumn.extensions array
      # 
      # Use this to prevent upload of files which could potentially damage your system,
      # such as executables or script files (.rb, .php, etc...).
      def validates_integrity_of(*attr_names)
        configuration = { :message => "is not of a valid file type." }
        configuration.update(attr_names.pop) if attr_names.last.is_a?(Hash)
      
        attr_names.each { |name| self.reflect_on_upload_columns[name].options[:validate_integrity] = true }
      
        validates_each(attr_names, configuration) do |record, attr, value|
          value = record.instance_variable_get('@files')[attr]
          record.errors.add(attr, value.message) if value.is_a?(IntegrityError)
        end
      end
    
      # returns a hash of all UploadColumns defined on the model and their options.
      def reflect_on_upload_columns
        @upload_columns || {}
      end
    
      private
      
      def define_submethod(name, *subs, &b)
        define_method([name, subs].join('_'), &b)
      end
    
      # This is mostly for testing
      def reset_upload_columns
        @upload_columns = {}
      end

    end
  
  end

end
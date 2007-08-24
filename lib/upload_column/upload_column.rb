require 'fileutils'
require 'tempfile'
require 'RMagick'
    
module UploadColumn
  def self.append_features(base) #:nodoc:
    super
    base.extend(ClassMethods)
    base.after_save :save_uploaded_files
  end
  
  EXTENSIONS = %w(asf avi css doc dvi gif gz html jpg js m3u mov mp3 mpeg odf pac pdf png ppt ps sig spl swf tar tar.gz torrent txt wav wax wm wma xbm xml xpm xsl xwd zip)
  IMAGE_EXTENSIONS = %w(jpg jpeg gif png)
  
  Column = Struct.new(:name, :options)
  
  private
  
  def save_uploaded_files
    @files.each { |k, v| v.send(:save) if v.tempfile? } if @files
  end

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
    # [+permissions+] Specify the Unix permissions to be used with UploadColumn. Defaults to 0644.
    # [+root_path+] The root path where image will be stored, it will be prepended to store_dir and tmp_dir
    # 
    # it also accepts the following, less common options:
    # [+web_root+] Prepended to all addresses returned by UploadColumn::BaseUploadedFile.url
    # [+extensions+] A white list of files that can be used together with validates_integrity_of to secure your uploads against malicious files.
    # [+fix_file_extensions+] Try to fix the file's extension based on its mime-type, note that this does not give you any security, to make sure that no dangerous files are uploaded, use validates_integrity_of. This defaults to true.
    # [+get_content_type_from_file_exec+] If this is set to true, UploadColumn::SanitizedFile will use a *nix exec to try to figure out the content type of the uploaded file.
    def upload_column(name, options = {})
      @upload_columns ||= {}
      @upload_columns[name] = Column.new(name, options)
      
      # Add the accessor methods
      define_method name do
        @files ||= {}
        @files[name] ||= if self[name] then UploadedFile.retrieve(self[name], self, name, options) else nil end
      end
      
      define_method "#{name}=" do |file|
        @files ||= {}
        if file.nil?
          @files[name], self[name] = nil
        else
          if uploaded_file = UploadedFile.upload(file, self, name, options)
            self[name] = uploaded_file.filename
            @files[name] = uploaded_file
          end
        end
      end
      
      # Add the accessor methods for temp
      define_method "#{name}_temp" do
        @files[name].temp_value if @files and @files[name]
      end
      
      define_method "#{name}_temp=" do |path|
        @files ||= {}
        unless @files[name] and @files[name].new_file?
          @files[name] = UploadedFile.retrieve_temp(path, self, name, options)
          self[name] = @files[name].filename
        end
      end
    end
    
    # returns a hash of all UploadColumns defined on the model and their options.
    def reflect_on_upload_columns
      @upload_columns
    end
    
    private
    
    # This is mostly for testing
    def reset_upload_columns
      @upload_columns = {}
    end

  end

end
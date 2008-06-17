begin; require 'mime/types'; rescue Exception; end

require 'fileutils'

module UploadColumn
  # Sanitize is a base class that takes care of all the dirtywork when dealing with file uploads.
  # it is subclassed as UploadedFile in UploadColumn, which does most of the upload magic, but if
  # you want to roll you own uploading system, SanitizedFile might be for you since it takes care
  # of a lot of the unfun stuff.
  # 
  # Usage is pretty simple, just do SanitizedFile.new(some_uploaded_file) and you're good to go
  # you can now use #copy_to and #move_to to place the file wherever you want, whether it is a StringIO
  # or a TempFile.
  #
  # SanitizedFile also deals with content type detection, which it does either through the 'file' *nix exec
  # or (if you are stuck on Windows) through the MIME::Types library (not to be confused with Rails' Mime class!).
  class SanitizedFile
    
    attr_reader :basename, :extension
    
    def initialize(file, options = {})
      @options = options
      if file && file.instance_of?(String) && !file.empty? 
        @path = file
        self.filename = File.basename(file)
      else
        @file = file
        self.filename = self.original_filename unless self.empty?
      end
    end
    
    # Returns the filename before sanitation took place
    def original_filename
      @original_filename ||= if @file and @file.respond_to?(:original_filename)
        @file.original_filename
      elsif self.path
        File.basename(self.path)
      end
    end
    
    # Returns the files properly sanitized filename.
    def filename
      @filename ||= (self.extension && !self.extension.empty?) ? "#{self.basename}.#{self.extension}" : self.basename
    end
    
    # Returns the file's size
    def size
      return @file.size if @file.respond_to?(:size)
      File.size(self.path) rescue nil
    end
    
    # Returns the full path to the file
    def path
      @path ||= File.expand_path(@file.path) rescue nil
    end
    
    # Checks if the file is empty.
    def empty?
      (@file.nil? && @path.nil?) || self.size.nil? || self.size.zero?
    end
    
    # Checks if the file exists
    def exists?
      File.exists?(self.path) if self.path
    end
    
    # Moves the file to 'path'
    def move_to(path)
      if copy_file(path)
        # FIXME: This gets pretty broken in UploadedFile. E.g. moving avatar-thumb.jpg will change the filename
        # to avatar-thumb-thumb.jpg
        @basename, @extension = split_extension(File.basename(path))
        @file = nil
        @filename = nil
        @path = path
      end
    end
    
    # Copies the file to 'path' and returns a new SanitizedFile that points to the copy.
    def copy_to(path)
      copy = self.clone
      copy.move_to(path)
      return copy
    end
    
    # Returns the content_type of the file as determined through the MIME::Types library or through a *nix exec.
    def content_type
      unless content_type = get_content_type_from_exec || get_content_type_from_mime_types
        content_type ||= @file.content_type.chomp if @file.respond_to?(:content_type) and @file.content_type
      end
      return content_type
    end
    
    private
    
    def copy_file(path)
      unless self.empty?
        # create the directory if it doesn't exist
        FileUtils.mkdir_p(File.dirname(path)) unless File.exists?(File.dirname(path))
        # stringios don't have a path and can't be copied
        if not self.path and @file.respond_to?(:read)
          @file.rewind # Make sure we are at the beginning of the buffer
          File.open(path, "wb") { |f| f.write(@file.read) }
        else
          begin
            FileUtils.cp(self.path, path)
          rescue ArgumentError
          end
        end
        File.chmod(@options[:permissions], path) if @options[:permissions]
        return true
      end
    end
    
    def filename=(filename)
      basename, extension = split_extension(filename)
      @basename = sanitize(basename)
      @extension = correct_file_extension(extension)
    end
    
    # tries to identify the mime-type of file and correct self's extension
    # based on the found mime-type
    def correct_file_extension(ext)
      if @options[:fix_file_extensions] && defined?(MIME::Types)
        if mimes = MIME::Types[self.content_type]
          return mimes.first.extensions.first unless mimes.first.extensions.empty?
        end
      end
      return ext.downcase
    end
    
    # Try to use *nix exec to fetch content type
    def get_content_type_from_exec
      if @options[:get_content_type_from_file_exec] and not self.path.empty?
        return system_call(%(file -bi "#{self.path}")).chomp.scan(/^[a-z0-9\-_]+\/[a-z0-9\-_]+/).first
      end
    rescue
      nil
    end
    
    def system_call(command)
      `#{command}`
    end
    
    def get_content_type_from_mime_types
      if @extension and defined?(MIME::Types)
        mimes = MIME::Types.of(@extension)
        return mimes.first.content_type rescue nil
      end
    end
    
    def sanitize(name)
      # Sanitize the filename, to prevent hacking
      name = File.basename(name.gsub("\\", "/")) # work-around for IE
      name.gsub!(/[^a-zA-Z0-9\.\-\+_]/,"_")
      name = "_#{name}" if name =~ /^\.+$/
      name = "unnamed" if name.size == 0
      return name.downcase
    end
    
    def split_extension(fn)
      # regular expressions to try for identifying extensions
      ext_regexps = [ 
        /^(.+)\.([^\.]{1,3}\.[^\.]{1,4})$/, # matches "something.tar.gz"
        /^(.+)\.([^\.]+)$/ # matches "something.jpg"
      ]
      ext_regexps.each do |regexp|
        if fn =~ regexp
          return $1, $2
        end
      end
      return fn, "" # In case we weren't able to split the extension
    end
    
  end
end
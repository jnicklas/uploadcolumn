require File.join(File.dirname(__FILE__), 'spec_helper')
require File.join(File.dirname(__FILE__), '../lib/upload_column/sanitized_file')
require File.join(File.dirname(__FILE__), '../lib/upload_column/uploaded_file')
begin
  require 'mime/types'
rescue LoadError
end

describe "SanitizedFile", :shared => true do
  
  describe "a new SanitizedFile" do
    it "should be empty on empty String, nil, empty StringIO" do
      UploadColumn::SanitizedFile.new("").should be_empty
      UploadColumn::SanitizedFile.new(StringIO.new("")).should be_empty
      UploadColumn::SanitizedFile.new(nil).should be_empty
      file = mock('emptyfile')
      file.should_receive(:size).at_least(:once).and_return(0)
      UploadColumn::SanitizedFile.new(file).should be_empty
    end
  
    it "should not be empty on valid upload" do
      UploadColumn::SanitizedFile.new(stub_stringio('kerb.jpg', 'image/jpeg')).should_not be_empty
      UploadColumn::SanitizedFile.new(stub_file('kerb.jpg', 'image/jpeg')).should_not be_empty
    end

    it "should sanitize invalid filenames" do
      t = UploadColumn::SanitizedFile.new(stub_file('kerb.jpg', nil, "test.jpg"))
      t.filename.should == "test.jpg"
    
      t = UploadColumn::SanitizedFile.new(stub_file('kerb.jpg', nil, "test-s,%&m#st?.jpg"))
      t.filename.should == "test-s___m_st_.jpg"
    
      t = UploadColumn::SanitizedFile.new(stub_file('kerb.jpg', nil, "../../very_tricky/foo.bar"))
      t.filename.should_not =~ /[\\\/]/
  
      t = UploadColumn::SanitizedFile.new(stub_file('kerb.jpg', nil, '`*foo'))
      t.filename.should == "__foo"
  
      t = UploadColumn::SanitizedFile.new(stub_file('kerb.jpg', nil, 'c:\temp\foo.txt'))
      t.filename.should == "foo.txt"
    
      t = UploadColumn::SanitizedFile.new(stub_file('kerb.jpg', nil, "."))
      t.filename.should == "_."
    end
    
    it "should downcase uppercase filenames" do
      t = UploadColumn::SanitizedFile.new(stub_file('kerb.jpg', nil, "DSC4056.JPG"))
      t.filename.should == "dsc4056.jpg"
    end
  
  end
  
  # Note that SanitizedFile#path and #exists? need to be checked seperately as the return values will vary
  describe "all sanitized files", :shared => true do
    
    it "should not be empty" do
      @file.should_not be_empty
    end

    it "should return the original filename" do
      @file.original_filename.should == "kerb.jpg"
    end

    it "should return the filename" do
      @file.filename.should == "kerb.jpg"
    end

    it "should return the basename" do
      @file.basename.should == "kerb"
    end

    it "should return the extension" do
      @file.extension.should == "jpg"
    end

    it "should be moved to the correct location" do
      @file.move_to(public_path('gurr.jpg'))
      File.exists?( public_path('gurr.jpg') ).should === true
      file_path('kerb.jpg').should be_identical_with(public_path('gurr.jpg'))
    end
    
    it "should have changed its path when moved" do
      @file.move_to(public_path('gurr.jpg'))
      @file.path.should match_path(public_path('gurr.jpg'))
    end
    
    it "should have changed its filename when moved" do
      @file.filename # Make sure the filename has been cached
      @file.move_to(public_path('gurr.jpg'))
      @file.filename.should == 'gurr.jpg'
    end
    
    it "should have split the filename when moved" do
      @file.move_to(public_path('gurr.monk'))
      @file.basename.should == 'gurr'
      @file.extension.should == 'monk'
    end
    
    it "should be copied to the correct location" do
      @file.copy_to(public_path('gurr.jpg'))
      File.exists?( public_path('gurr.jpg') ).should === true
      file_path('kerb.jpg').should be_identical_with(public_path('gurr.jpg'))
    end
    
    it "should not have changed its path when copied" do
      lambda do
        @file.copy_to(public_path('gurr.jpg'))
      end.should_not change(@file, :path)
    end
    
    it "should not have changed its filename when copied" do
      lambda do
        @file.copy_to(public_path('gurr.jpg'))
      end.should_not change(@file, :filename)
    end
    
    it "should return an object of the same class when copied" do
      @file = @file.copy_to(public_path('gurr.jpg'))
      @file.should be_an_instance_of(@file.class)
    end
    
    it "should adjust the path of the object that is returned when copied" do
      @file = @file.copy_to(public_path('gurr.jpg'))
      @file.path.should match_path(public_path('gurr.jpg'))
    end

    it "should adjust the filename of the object that is returned when copied" do
      @file.filename # Make sure the filename has been cached
      @file = @file.copy_to(public_path('gurr.monk'))
      @file.filename.should == 'gurr.monk'
    end

    it "should split the filename of the object that is returned when copied" do
      @file = @file.copy_to(public_path('gurr.monk'))
      @file.basename.should == 'gurr'
      @file.extension.should == 'monk'
    end
    
    after do
      FileUtils.rm_rf(PUBLIC)
    end
  end
  
  describe "a sanitized Tempfile" do
    before do
      @file = UploadColumn::SanitizedFile.new(stub_tempfile('kerb.jpg', 'image/jpeg'))
    end
  
    it_should_behave_like "all sanitized files"
    
    it "should exist" do
      @file.should be_in_existence
    end
  
    it "should return the correct path" do
      @file.path.should_not == nil
      @file.path.should =~ %r{^/tmp/kerb.jpg}
    end
  end

  describe "a sanitized StringIO" do
    before do
      @file = UploadColumn::SanitizedFile.new(stub_stringio('kerb.jpg', 'image/jpeg'))
    end
    
    it_should_behave_like "all sanitized files"
    
    it "should not exist" do
      @file.should_not be_in_existence
    end
  
    it "should return no path" do
      @file.path.should == nil
    end
    
  end

  describe "a sanitized File object" do
    before do
      @file = UploadColumn::SanitizedFile.new(stub_file('kerb.jpg', 'image/jpeg'))
      @file.should_not be_empty
    end
    
    it_should_behave_like "all sanitized files"
    
    it "should exits" do
      @file.should be_in_existence
    end
  
    it "should return correct path" do
      @file.path.should match_path(file_path('kerb.jpg'))
    end
  end

  describe "a SanitizedFile opened from a path" do
    before do
      @file = UploadColumn::SanitizedFile.new(file_path('kerb.jpg'))
      @file.should_not be_empty
    end
    
    it_should_behave_like "all sanitized files"
    
    it "should exits" do
      @file.should be_in_existence
    end
  
    it "should return correct path" do
      @file.path.should == file_path('kerb.jpg')
    end
  end

  describe "an empty SanitizedFile" do
    before do
      @empty = UploadColumn::SanitizedFile.new(nil)
    end
  
    it "should be empty" do
      @empty.should be_empty
    end
    
    it "should not exist" do
      @empty.should_not be_in_existence
    end
  
    it "should have no size" do
      @empty.size.should == nil
    end
  
    it "should have no path" do
      @empty.path.should == nil
    end
  
    it "should have no original filename" do
      @empty.original_filename.should == nil
    end
  
    it "should have no filename" do
      @empty.filename.should == nil
    end
  
    it "should have no basename" do
      @empty.basename.should == nil
    end
  
    it "should have no extension" do
      @empty.extension.should == nil
    end
  end

  describe "a SanitizedFile" do
  
    before do
      @file = UploadColumn::SanitizedFile.new(stub_tempfile('kerb.jpg', 'image/jpeg'))
    end
  
    it "should properly split into basename and extension" do
      @file.basename.should == "kerb"
      @file.extension.should == "jpg"
    end
    
    it "should do a system call" do
      @file.send(:system_call, 'echo "monkey"').chomp.should == "monkey"
    end
  
  end

  describe "a SanizedFile with a complex filename" do
    it "properly split into basename and extension" do
      t = UploadColumn::SanitizedFile.new(stub_tempfile('kerb.jpg', nil, 'complex.filename.tar.gz'))
      t.basename.should == "complex.filename"
      t.extension.should == "tar.gz"
    end
  end
  
  # FIXME: figure out why this doesn't run
  #describe "determinating the mime-type with a *nix exec" do
  #
  #  before do
  #    @file = stub_file('kerb.jpg', nil, 'harg.css')
  #    @sanitized = UploadColumn::SanitizedFile.new(@file)
  #  end
  #  
  #  it "should chomp and return if it has no encoding" do
  #    @sanitized.should_receive(:system_call).with(%(file -bi "#{@file.path}")).and_return("image/jpeg\n")
  #    
  #    @sanitized.send(:get_content_type_from_exec) #.should == "image/jpeg"
  #  end
  #  
  #  it "should chomp and return and chop off the encoding if it has one" do
  #    @sanitized.should_receive(:system_call).with(%(file -bi "#{@file.path}")).and_return("text/plain; charset=utf-8;\n")
  #    
  #    @sanitized.send(:get_content_type_from_exec) #.should == "text/plain"
  #  end
  #  
  #  it "should not crap out when something weird happens" do
  #    @sanitized.should_receive(:system_call).with(%(file -bi "#{@file.path}")).and_return("^blah//(?)wtf???")
  #    
  #    @sanitized.send(:get_content_type_from_exec).should == nil
  #  end
  #  
  #end

  describe "The mime-type of a Sanitized File" do
  
    before do
      @file = stub_file('kerb.jpg', nil, 'harg.css')
      @sanitized = UploadColumn::SanitizedFile.new(@file)
    end

    # TODO: refactor this test so it mocks out system_call
    it "should be determined via *nix exec" do
      @file.should_not_receive(:content_type)
      @sanitized.should_not_receive(:extension)
      @sanitized.should_receive(:get_content_type_from_exec).and_return('image/jpeg')
      @sanitized.content_type.should == "image/jpeg"
    end
    
    it "shouldn't choke up when the *nix exec errors out" do
      lambda {
        @sanitized.should_receive(:system_call).and_raise('monkey')
        @sanitized.content_type
      }.should_not raise_error(Exception)
    end
  
    it "should otherwise be loaded from MIME::Types" do
      if defined?(MIME::Types)
        @sanitized.should_receive(:get_content_type_from_exec).and_return(nil) # Make sure the *nix exec isn't interfering
        @sanitized.content_type.should == "text/css"
      else
        puts "WARNING: Could not run all tests because MIME::Types is not defined, try installing the mime-types gem!"
      end
    end
  
    it "should be taken from the browser if all else fails" do
      @file.should_receive(:content_type).at_least(:once).and_return('application/xhtml+xml') # Set up browser behavior
      @sanitized.should_receive(:get_content_type_from_mime_types).and_return(nil) # Make sure MIME::Types isn't interfering
      @sanitized.should_receive(:get_content_type_from_exec).and_return(nil) # Make sure the *nix exec isn't interfering
      @sanitized.content_type.should == "application/xhtml+xml"
    end
  end

  describe "a SanitizedFile with a wrong extension" do

    # This test currently always fails if MIME::Types is unavailable,
    # TODO: come up with a clever way to stub out the content_type-y behaviour.
    it "should fix extention if fix_file_extensions is true" do
      t = UploadColumn::SanitizedFile.new(stub_file('kerb.jpg', 'image/jpeg', 'kerb.css'), :fix_file_extensions => true)
            
      t.content_type.should == "image/jpeg"
      t.extension.should ==  "jpeg"
      t.filename.should == "kerb.jpeg"
    end
  
    it "should not fix extention if fix_file_extensions is false" do
      t = UploadColumn::SanitizedFile.new(stub_file('kerb.jpg', 'image/jpeg', 'kerb.css'), :fix_file_extensions => false)
      
      t.content_type.should == "image/jpeg"
      t.extension.should == "css"
      t.filename.should == "kerb.css"
    end
  end
  
  describe "a sanitized Tempfile" do
    before do
      @file = UploadColumn::SanitizedFile.new(stub_tempfile('kerb.jpg', 'image/jpeg'))
    end
  
    it_should_behave_like "all sanitized files"
    
    it "should exist" do
      @file.should be_in_existence
    end
  
    it "should return the correct path" do
      @file.path.should_not == nil
      @file.path.should =~ %r{^/tmp/kerb.jpg}
    end
  end
  
  describe "copying a sanitized Tempfile with permissions set" do
    before do
      @file = UploadColumn::SanitizedFile.new(stub_tempfile('kerb.jpg', 'image/jpeg'), :permissions => 0755)
      @file = @file.copy_to(public_path('gurr.jpg'))
    end
    
    it "should set the right permissions" do
      @file.should have_permissions(0755)
    end
  end

  describe "copying a sanitized StringIO with permissions set" do
    before do
      @file = UploadColumn::SanitizedFile.new(stub_stringio('kerb.jpg', 'image/jpeg'), :permissions => 0755)
      @file = @file.copy_to(public_path('gurr.jpg'))
    end
    
    it "should set the right permissions" do
      @file.should have_permissions(0755)
    end
  end
  
  describe "copying a sanitized File object with permissions set" do
    before do
      @file = UploadColumn::SanitizedFile.new(stub_file('kerb.jpg', 'image/jpeg'), :permissions => 0755)
      @file = @file.copy_to(public_path('gurr.jpg'))
    end
    
    it "should set the right permissions" do
      @file.should have_permissions(0755)
    end
  end
  
  describe "copying a sanitized StringIO with permissions set" do
    before do
      @file = UploadColumn::SanitizedFile.new(file_path('kerb.jpg'), :permissions => 0755)
      @file = @file.copy_to(public_path('gurr.jpg'))
    end
    
    it "should set the right permissions" do
      @file.should have_permissions(0755)
    end
  end
  
  
  describe "moving a sanitized Tempfile with permissions set" do
    before do
      @file = UploadColumn::SanitizedFile.new(stub_tempfile('kerb.jpg', 'image/jpeg'), :permissions => 0755)
      @file.move_to(public_path('gurr.jpg'))
    end
    
    it "should set the right permissions" do
      @file.should have_permissions(0755)
    end
  end

  describe "moving a sanitized StringIO with permissions set" do
    before do
      @file = UploadColumn::SanitizedFile.new(stub_stringio('kerb.jpg', 'image/jpeg'), :permissions => 0755)
      @file.move_to(public_path('gurr.jpg'))
    end
    
    it "should set the right permissions" do
      @file.should have_permissions(0755)
    end
  end
  
  describe "moving a sanitized File object with permissions set" do
    before do
      @file = UploadColumn::SanitizedFile.new(stub_file('kerb.jpg', 'image/jpeg'), :permissions => 0755)
      @file.move_to(public_path('gurr.jpg'))
    end
    
    it "should set the right permissions" do
      @file.should have_permissions(0755)
    end
  end
  
  describe "moving a sanitized StringIO with permissions set" do
    before do
      @file = UploadColumn::SanitizedFile.new(file_path('kerb.jpg'), :permissions => 0755)
      @file.move_to(public_path('gurr.jpg'))
    end
    
    it "should set the right permissions" do
      @file.should have_permissions(0755)
    end
  end
  
end




############### UploadedFile ###############

describe "UploadedFile" do
  it_should_behave_like "SanitizedFile"
  
  describe "all uploaded files", :shared => true do
    it "should not be empty" do
      @file.should_not be_empty
    end

    it "should return the correct filesize" do
      @file.size.should == 87582
    end

    it "should return the original filename" do
      @file.original_filename.should == "kerb.jpg"
    end

    it "should return the filename" do
      @file.filename.should == "kerb.jpg"
    end

    it "should return the basename" do
      @file.basename.should == "kerb"
    end

    it "should return the extension" do
      @file.extension.should == "jpg"
    end
    
    after do
      FileUtils.rm_rf(public_path('*'))
    end
  end
  
  describe "an uploaded tempfile" do
    
    before do
      @file = UploadColumn::UploadedFile.upload(stub_tempfile('kerb.jpg'))
    end
    
    it_should_behave_like "all uploaded files"
    
    it "should return the correct path" do
      @file.path.should match_path('public', 'tmp', %r{((\d+\.)+\d+)}, 'kerb.jpg')
    end
    
    it "should return the correct relative_path" do
      @file.relative_path.should =~ %r{^tmp/((\d+\.)+\d+)/kerb.jpg}
    end
    
    it "should return correct dir" do
      @file.dir.should match_path('public', 'tmp', %r{((\d+\.)+\d+)})
    end
  end
  
  describe "an uploaded StringIO" do
    
    before do
      @file = UploadColumn::UploadedFile.upload(stub_stringio('kerb.jpg'))
    end
    
    it_should_behave_like "all uploaded files"
    
    it "should return the correct path" do
      @file.path.should match_path('public', 'tmp', %r{((\d+\.)+\d+)}, 'kerb.jpg')
    end
    
    it "should return the correct relative_path" do
      @file.relative_path.should =~ %r{^tmp/((\d+\.)+\d+)/kerb.jpg}
    end
    
    it "should return correct dir" do
      @file.dir.should match_path('public', 'tmp', %r{((\d+\.)+\d+)})
    end
  end
  
  describe "an uploaded File object" do
    
    before do
      @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'))
    end
    
    it_should_behave_like "all uploaded files"
    
    it "should return the correct path" do
      @file.path.should match_path('public', 'tmp', %r{((\d+\.)+\d+)}, 'kerb.jpg')
    end
    
    it "should return the correct relative_path" do
      @file.relative_path.should =~ %r{^tmp/((\d+\.)+\d+)/kerb.jpg}
    end
    
    it "should return correct dir" do
      @file.dir.should match_path('public', 'tmp', %r{((\d+\.)+\d+)})
    end
  end
  
  describe "an uploaded non-empty String" do
    it "should raise an error" do
      lambda do
        UploadColumn::UploadedFile.upload("../README")
      end.should raise_error(UploadColumn::UploadNotMultipartError)
    end
  end
  
  describe "an uploded empty file" do
    it "should return nil" do    
      file = mock('uploaded empty file')
      file.should_receive(:empty?).and_return(true)
      upload = mock('upload')
      UploadColumn::UploadedFile.should_receive(:new).and_return(file)
    
      UploadColumn::UploadedFile.upload(upload).should == nil
    end
  end
  
  describe "an UploadedFile" do
    before do
      @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), nil, :donkey)
    end
    
    it "should have the correct relative store dir" do
      @file.relative_store_dir.should == 'donkey'
    end
    
    it "should have the correct store dir" do
      @file.store_dir.should == File.expand_path('donkey', PUBLIC)
    end
    
    it "should have the correct relative tmp dir" do
      @file.relative_tmp_dir.should == 'tmp'
    end
    
    it "should have the correct tmp dir" do
      @file.tmp_dir.should == File.expand_path('tmp', PUBLIC)
    end
    
    it "should return something sensible on inspect" do
      @file.inspect.should == "<UploadedFile: #{@file.path}>"
    end
  end
  
  describe "an UploadedFile where store_dir is a String" do
    before do
      @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), nil, nil, :store_dir => 'monkey')
    end
    
    it "should have the correct relative store dir" do
      @file.relative_store_dir.should == 'monkey'
    end
    
    it "should have the correct store dir" do
      @file.store_dir.should == File.expand_path('monkey', PUBLIC)
    end
  end
  
  describe "an UploadedFile where tmp_dir is a String" do
    before do
      @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), nil, nil, :tmp_dir => 'monkey')
    end
    
    it "should have the correct relative tmp dir" do
      @file.relative_tmp_dir.should == 'monkey'
    end
    
    it "should have the correct tmp dir" do
      @file.tmp_dir.should == File.expand_path('monkey', PUBLIC)
    end
  end
  
  describe "an UploadedFile where store_dir is a simple Proc" do
    before do
      @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), nil, nil, :store_dir => proc{'monkey'})
    end
    
    it "should have the correct relative store dir" do
      @file.relative_store_dir.should == 'monkey'
    end
    
    it "should have the correct store dir" do
      @file.store_dir.should == File.expand_path('monkey', PUBLIC)
    end
  end
  
  describe "an UploadedFile where tmp_dir is a simple Proc" do
    before do
      @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), nil, nil, :tmp_dir => proc{'monkey'})
    end
    
    it "should have the correct relative tmp dir" do
      @file.relative_tmp_dir.should == 'monkey'
    end
    
    it "should have the correct tmp dir" do
      @file.tmp_dir.should == File.expand_path('monkey', PUBLIC)
    end
  end
  
  describe "an UploadedFile where store_dir is a Proc and has the record piped in" do
    before do
      record = mock('a record')
      record.stub!(:name).and_return('quack')
      @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), record, nil, :store_dir => proc{ |record| File.join(record.name, 'monkey')})
    end
    
    it "should have the correct relative store dir" do
      @file.relative_store_dir.should == 'quack/monkey'
    end
    
    it "should have the correct store dir" do
      @file.store_dir.should == File.expand_path('quack/monkey', PUBLIC)
    end
  end
  
  describe "an UploadedFile where tmp_dir is a Proc and has the record piped in" do
    before do
      record = mock('a record')
      record.stub!(:name).and_return('quack')    
      @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), record, nil, :tmp_dir => proc{ |record| File.join(record.name, 'monkey')})
    end
    
    it "should have the correct relative tmp dir" do
      @file.relative_tmp_dir.should == 'quack/monkey'
    end
    
    it "should have the correct tmp dir" do
      @file.tmp_dir.should == File.expand_path('quack/monkey', PUBLIC)
    end
  end
  
  
  describe "an UploadedFile where store_dir is a Proc and has the record and file piped in" do
    before do
      record = mock('a record')
      record.stub!(:name).and_return('quack')
      @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), record, nil, :store_dir => proc{ |r, f| File.join(record.name, f.basename, 'monkey')})
    end
    
    it "should have the correct relative store dir" do
      @file.relative_store_dir.should == 'quack/kerb/monkey'
    end
    
    it "should have the correct store dir" do
      @file.store_dir.should == File.expand_path('quack/kerb/monkey', PUBLIC)
    end
  end
  
  describe "an UploadedFile where tmp_dir is a Proc and has the record and file piped in" do
    before do
      record = mock('a record')
      record.stub!(:name).and_return('quack')    
      @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), record, nil, :tmp_dir => proc{ |r, f| File.join(record.name, f.basename, 'monkey')})
    end
    
    it "should have the correct relative tmp dir" do
      @file.relative_tmp_dir.should == 'quack/kerb/monkey'
    end
    
    it "should have the correct tmp dir" do
      @file.tmp_dir.should == File.expand_path('quack/kerb/monkey', PUBLIC)
    end
  end

  
  describe "an UploadedFile with a store_dir callback" do
    before do
      i = mock('instance with store_dir callback')
      i.should_receive(:monkey_store_dir).and_return('llama')
      @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), i, :monkey)
    end
    
    it "should have the correct relative store dir" do
      @file.relative_store_dir.should == 'llama'
    end
    
    it "should have the correct store dir" do
      @file.store_dir.should == File.expand_path('llama', PUBLIC)
    end
  end
  
  describe "an UploadedFile with a tmp_dir callback" do
    before do
      i = mock('instance with a tmp_dir callback')
      i.should_receive(:monkey_tmp_dir).and_return('gorilla')
      @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), i, :monkey)
    end
    
    it "should have the correct relative tmp dir" do
      @file.relative_tmp_dir.should == 'gorilla'
    end
    
    it "should have the correct tmp dir" do
      @file.tmp_dir.should == File.expand_path('gorilla', PUBLIC)
    end
  end
  
  describe "an UploadedFile with a tmp_dir callback" do
    before do
      i = mock('instance with a tmp_dir callback')
      i.should_receive(:monkey_tmp_dir).and_return('gorilla')
      @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), i, :monkey)
    end
    
    it "should have the correct relative tmp dir" do
      @file.relative_tmp_dir.should == 'gorilla'
    end
    
    it "should have the correct tmp dir" do
      @file.tmp_dir.should == File.expand_path('gorilla', PUBLIC)
    end
  end
  
  describe "an UploadedFile with a tmp_dir callback" do
    before do
      i = mock('instance with a tmp_dir callback')
      i.should_receive(:monkey_tmp_dir).and_return('gorilla')
      @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), i, :monkey)
    end
    
    it "should have the correct relative tmp dir" do
      @file.relative_tmp_dir.should == 'gorilla'
    end
    
    it "should have the correct tmp dir" do
      @file.tmp_dir.should == File.expand_path('gorilla', PUBLIC)
    end
  end
  
  describe "an UploadedFile that has just been uploaded" do

    before do
      @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, :monkey)
    end
    
    it_should_behave_like "all uploaded files"
    
    it "should be new" do
      @file.should be_new_file
    end
    
    it "should exist" do
      @file.should be_in_existence
    end
    
    it "should be stored in tmp" do
      @file.path.should match_path('public', 'tmp', %r{((\d+\.)+\d+)}, 'kerb.jpg')
    end
    
  end
  
  describe "saving an UploadedFile" do
    before do
      @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, :monkey)
    end
    
    it "should return true" do
      @file.send(:save).should === true
    end
    
    it "should copy the file to the correct location" do
      @file.send(:save)
      @file.path.should match_path('public', 'monkey', 'kerb.jpg')
      @file.should be_in_existence
    end
    
    after do
      FileUtils.rm_rf(PUBLIC)
    end
    
  end
  
  describe "a saved UploadedFile" do
    before do
      @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, :monkey)
      @file.send(:save)
    end
    
    it_should_behave_like "all uploaded files"
    
    it "should not be new" do
      @file.should_not be_new_file
    end
    
    it "should return the correct path" do
      @file.path.should match_path('public', 'monkey', 'kerb.jpg')
    end
    
    it "should return the correct relative_path" do
      @file.relative_path.should == "monkey/kerb.jpg"
    end
    
    it "should return the correct dir" do
      @file.dir.should match_path('public', 'monkey')
    end

    after do
      FileUtils.rm_rf(PUBLIC)
    end
    
  end
  
  describe "an UploadedFile with a manipulator" do
    before do
      a_manipulator = Module.new
      a_manipulator.send(:define_method, :monkey! ) { |stuff| stuff }
      @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), nil, :donkey, :manipulator => a_manipulator)
    end
    
    it "should extend the object with the manipulator methods." do
      @file.should respond_to(:monkey!)
    end
    
  end
  
  describe "an UploadedFile with a manipulator with dependencies" do
  
    it "should extend the object with the manipulator methods and load dependencies." do
      process_proxy = mock('nothing in particular')
      a_manipulator = Module.new
      a_manipulator.send(:define_method, :monkey! ) { |stuff| stuff }
      a_manipulator.send(:define_method, :load_manipulator_dependencies) do
        # horrible abuse of Ruby's closures. This allows us to set expectations on the process_proxy
        # and if process! is called, the process_proxy will be adressed instead.
        process_proxy.load_manipulator_dependencies
      end
      
      process_proxy.should_receive(:load_manipulator_dependencies)
      
      @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), nil, :donkey, :manipulator => a_manipulator)

      @file.should respond_to(:monkey!)
    end
    
  end
  
  describe "an UploadedFile with a manipulator and process instruction" do
    
    it "should process before iterating versions" do
      process_proxy = mock('nothing in particular')
      a_manipulator = Module.new
      a_manipulator.send(:define_method, :process!) do |*args|
        process_proxy.process!(*args)
      end
      # this will override the base classes initialize_versions option, so we can catch it.
      a_manipulator.send(:define_method, :initialize_versions) do |*args|
        process_proxy.initialize_versions *args
      end

      process_proxy.should_receive(:process!).with('100x100').ordered
      process_proxy.should_receive(:initialize_versions).ordered


      @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, :donkey, :process => '100x100', :manipulator => a_manipulator)
    end

  end
  
  describe "an UploadedFile with no versions" do
    it "should not respond to version methods" do
      @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, :monkey)
      @file.should_not respond_to(:thumb)
      @file.should_not respond_to(:large)
    end
  end
  
  describe "an UploadedFile with versions with illegal names" do
    it "should raise an ArgumentError" do
      lambda do
        @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, :monkey, :versions => [ :thumb, :path ])
      end.should raise_error(ArgumentError, 'path is an illegal name for an UploadColumn version.')
    end
  end
  
  describe "an UploadedFile with versions" do
    before do
      @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, :monkey, :versions => [ :thumb, :large ])
    end
    
    it "should respond to version methods" do
      @file.should respond_to(:thumb)
      @file.should respond_to(:large)
    end
    
    it "should return an UploadedFile instance when a version method is called" do
      @file.thumb.should be_instance_of(UploadColumn::UploadedFile)
      @file.large.should be_instance_of(UploadColumn::UploadedFile)
    end
  end
  
  describe "all versions of uploaded files", :shared => true do
    it "should return the filename including the version" do
      @thumb.filename.should == "kerb-thumb.jpg"
      @large.filename.should == "kerb-large.jpg"
    end
  
    it "should return the basename including the version" do
      @thumb.basename.should == "kerb-thumb"
      @large.basename.should == "kerb-large"
    end
  
    it "should return the extension" do
      @thumb.extension.should == "jpg"
      @large.extension.should == "jpg"
    end
    
    it "should return the correct suffix" do
      @thumb.suffix.should == :thumb
      @large.suffix.should == :large
    end
  end
  
  describe "a version of an uploaded UploadedFile" do
    before do
      @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, :monkey, :versions => [ :thumb, :large ])
      @thumb = @file.thumb
      @large = @file.large
    end
    
    it_should_behave_like "all versions of uploaded files"
    
    it "should not be empty" do
      @thumb.should_not be_empty
      @large.should_not be_empty
    end
  
    it "should return the correct filesize" do
      @thumb.size.should == 87582
      @large.size.should == 87582
    end
  
    it "should return the original filename" do
      @thumb.original_filename.should == "kerb.jpg"
      @large.original_filename.should == "kerb.jpg"
    end
  end

  describe "uploading a file with versions as a Hash" do
    
    it "should process the files with the manipulator" do
      
      process_proxy = mock('nothing in particular')
      a_manipulator = Module.new
      a_manipulator.send(:define_method, :process! ) do |stuff|
        # horrible abuse of Ruby's closures. This allows us to set expectations on the process_proxy
        # and if process! is called, the process_proxy will be adressed instead.
        process_proxy.process!(self.filename, stuff)
      end
      
      process_proxy.should_receive(:process!).with('kerb-thumb.jpg', '200x200')
      process_proxy.should_receive(:process!).with('kerb-large.jpg', '300x300')
      
      @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, :donkey, :manipulator => a_manipulator, :versions => { :thumb => '200x200', :large => '300x300' })
      @thumb = @file.thumb
      @large = @file.large
    end
    
  end
  
  
  describe "an version of an UploadedFile with versions as a hash" do
    
    before(:each) do
      process_proxy = mock('nothing in particular')
      a_manipulator = Module.new
      a_manipulator.send(:define_method, :process! ) { |stuff| true }
      @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, :donkey, :manipulator => a_manipulator, :versions => { :thumb => '200x200', :large => '300x300' })
      @thumb = @file.thumb
      @large = @file.large
    end
    
    it_should_behave_like "all versions of uploaded files"
    
    it "should not be empty" do
      @thumb.should_not be_empty
      @large.should_not be_empty
    end
  
    it "should return the original filename" do
      @thumb.original_filename.should == "kerb.jpg"
      @large.original_filename.should == "kerb.jpg"
    end
  
  end
  
  describe "a retrieved UploadedFile" do
    
    before do
      @file = UploadColumn::UploadedFile.retrieve('kerb.jpg', nil, :monkey)
      @file.stub!(:size).and_return(87582)
    end
    
    it_should_behave_like "all uploaded files"
    
    it "should not be new" do
      @file.should_not be_new_file
    end
    
    it "should return the correct path" do
      @file.path.should match_path(public_path('monkey/kerb.jpg'))
    end
  end
  
  describe "a version of a retrieved UploadedFile" do
    
    before do
      @file = UploadColumn::UploadedFile.retrieve('kerb.jpg', nil, :monkey, :versions => [:thumb, :large])
      @thumb = @file.thumb
      @large = @file.large
    end
    
    it_should_behave_like "all versions of uploaded files"
    
    it "should not be new" do
      @file.should_not be_new_file
    end
    
    it "should return the correct path" do
      @thumb.path.should match_path(public_path('monkey/kerb-thumb.jpg'))
      @large.path.should match_path(public_path('monkey/kerb-large.jpg'))
    end
    
    # Since the files don't exist in fixtures/ it wouldn't make sense to test their size
  end
  
  describe "a version of a saved UploadedFile" do
    before do
      @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, :monkey, :versions => [:thumb, :large])
      @file.send(:save)
      @thumb = @file.thumb
      @large = @file.large
    end
    
    it_should_behave_like "all versions of uploaded files"
    
    it "should not be new" do
      @file.should_not be_new_file
    end
    
    it "should return the correct path" do
      @thumb.path.should match_path('public', 'monkey', 'kerb-thumb.jpg')
      @large.path.should match_path('public', 'monkey', 'kerb-large.jpg')
    end
  end
  
  describe "opening a temporary UploadedFile" do
  
    it "should raise an error if the path is incorrectly formed" do
      lambda do
        @file = UploadColumn::UploadedFile.retrieve_temp(file_path('kerb.jpg'))
      end.should raise_error(UploadColumn::TemporaryPathMalformedError, "#{file_path('kerb.jpg')} is not a valid temporary path!")
    end
    
    it "should raise an error if its in a subdirectory" do
      lambda do
        @file = UploadColumn::UploadedFile.retrieve_temp('somefolder/1234.56789.1234/donkey.jpg;llama.png')
      end.should raise_error(UploadColumn::TemporaryPathMalformedError, "somefolder/1234.56789.1234/donkey.jpg;llama.png is not a valid temporary path!")
    end
    
    it "should raise an error if its relative" do
      lambda do
        @file = UploadColumn::UploadedFile.retrieve_temp('../1234.56789.1234/donkey.jpg;llama.png')
      end.should raise_error(UploadColumn::TemporaryPathMalformedError, "../1234.56789.1234/donkey.jpg;llama.png is not a valid temporary path!")
    end
    
    it "should raise an error if the filename is omitted" do
      lambda do
        @file = UploadColumn::UploadedFile.retrieve_temp('1234.56789.1234;llama.png')
      end.should raise_error(UploadColumn::TemporaryPathMalformedError, "1234.56789.1234;llama.png is not a valid temporary path!")
    end
    
    it "should not raise an error on nil" do
      lambda do
        @file = UploadColumn::UploadedFile.retrieve_temp(nil)
      end.should_not raise_error
    end

    it "should not raise an error on empty String" do
      lambda do
        @file = UploadColumn::UploadedFile.retrieve_temp('')
      end.should_not raise_error
    end
  end
  
  describe "a retrieved temporary UploadedFile" do
    
    before(:all) do
      FileUtils.mkdir_p(public_path('tmp/123455.1233.1233'))
      FileUtils.cp(file_path('kerb.jpg'), public_path('tmp/123455.1233.1233/kerb.jpg'))
    end
    
    before do
      @file = UploadColumn::UploadedFile.retrieve_temp('123455.1233.1233/kerb.jpg')
    end
    
    it_should_behave_like "all uploaded files"
    
    it "should not be new" do
      @file.should_not be_new_file
    end
    
    it "should return the correct path" do
      @file.path.should match_path('public', 'tmp', '123455.1233.1233', 'kerb.jpg')
    end
    
    after(:all) do
      FileUtils.rm_rf(PUBLIC)
    end
  end
  
  describe "a retrieved temporary UploadedFile with an appended original filename" do
    before(:all) do
      FileUtils.mkdir_p(public_path('tmp/123455.1233.1233'))
      FileUtils.cp(file_path('kerb.jpg'), public_path('tmp/123455.1233.1233/kerb.jpg'))
    end
    
    before do
      @file = UploadColumn::UploadedFile.retrieve_temp('123455.1233.1233/kerb.jpg;monkey.png')
    end
    
    it "should not be new" do
      @file.should_not be_new_file
    end
    
    it "should return the correct original filename" do
      @file.original_filename.should == "monkey.png"
    end
    
    it "should return the correct path" do
      @file.path.should match_path('public', 'tmp', '123455.1233.1233', 'kerb.jpg')
    end
    
    after(:all) do
      FileUtils.rm_rf(PUBLIC)
    end
  end
  
  describe "a version of a retrieved temporary UploadedFile" do
    
    before(:all) do
      FileUtils.mkdir_p(public_path('tmp/123455.1233.1233'))
      FileUtils.cp(file_path('kerb.jpg'), public_path('tmp/123455.1233.1233/kerb.jpg'))
    end
    
    before do
      @file = UploadColumn::UploadedFile.retrieve_temp('123455.1233.1233/kerb.jpg', nil, :monkey, :versions => [:thumb, :large])
      @thumb = @file.thumb
      @large = @file.large
    end
    
    it_should_behave_like "all versions of uploaded files"
    
    it "should not be new" do
      @file.should_not be_new_file
    end
    
    it "should return the correct path" do
      @thumb.path.should match_path(public_path('tmp/123455.1233.1233/kerb-thumb.jpg'))
      @large.path.should match_path(public_path('tmp/123455.1233.1233/kerb-large.jpg'))
    end
    
    after(:all) do
      FileUtils.rm_rf(PUBLIC)
    end
  end
  
  describe "uploading a file with validate_integrity set to true" do
    
    it "should raise an error if no extensions are set" do
      lambda do
        @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, nil, :validate_integrity => true)
      end.should raise_error(UploadColumn::IntegrityError)
    end

    it "should not raise an error if the extension is in extensions" do
      lambda do
        @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, nil, :validate_integrity => true, :extensions => %w(jpg gif png))
      end.should_not raise_error
    end
    
    it "should raise an error if the extension is not in extensions" do
      lambda do
        @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, nil, :validate_integrity => true, :extensions => %w(doc gif png))
      end.should raise_error(UploadColumn::IntegrityError)
    end
  end
  
  describe "An UploadedFile with no web_root set" do
    it "should return the correct URL and to_s" do
      @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, :donkey, :versions => [:thumb, :large])
      @file.send(:save)
      
      @file.url.should == "/donkey/kerb.jpg"
      @file.to_s.should == "/donkey/kerb.jpg"
      @file.thumb.url.should == "/donkey/kerb-thumb.jpg"
      @file.large.url.should == "/donkey/kerb-large.jpg"
    end
  end
  
  describe "An UploadedFile with no web_root set and MS style slashes in its relative path" do
    it "should return the correct URL and to_s" do
      @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, :donkey, :versions => [:thumb, :large])
      
      @file.should_receive(:relative_path).at_least(:once).and_return('stylesheets\something\monkey\kerb.jpg')
      @file.thumb.should_receive(:relative_path).at_least(:once).and_return('stylesheets\something\monkey\kerb-thumb.jpg')
      @file.large.should_receive(:relative_path).at_least(:once).and_return('stylesheets\something\monkey\kerb-large.jpg')
      
      @file.send(:save)
      
      @file.url.should == "/stylesheets/something/monkey/kerb.jpg"
      @file.to_s.should == "/stylesheets/something/monkey/kerb.jpg"
      @file.thumb.url.should == "/stylesheets/something/monkey/kerb-thumb.jpg"
      @file.large.url.should == "/stylesheets/something/monkey/kerb-large.jpg"
    end
  end
  
  describe "An UploadedFile with an absolute web_root set" do
    it "should return the correct URL and to_s" do
      @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, :donkey, :web_root => 'http://ape.com', :versions => [:thumb, :large])
      @file.send(:save)
      
      @file.url.should == "http://ape.com/donkey/kerb.jpg"
      @file.to_s.should == "http://ape.com/donkey/kerb.jpg"
      @file.thumb.url.should == "http://ape.com/donkey/kerb-thumb.jpg"
      @file.large.url.should == "http://ape.com/donkey/kerb-large.jpg"
    end
  end
  
  describe "An UploadedFile with an absolute web_root set and MS style slashes in its relative path" do
    it "should return the correct URL and to_s" do
      @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, :donkey, :web_root => 'http://ape.com', :versions => [:thumb, :large])
      @file.should_receive(:relative_path).at_least(:once).and_return('stylesheets\something\monkey\kerb.jpg')
      @file.thumb.should_receive(:relative_path).at_least(:once).and_return('stylesheets\something\monkey\kerb-thumb.jpg')
      @file.large.should_receive(:relative_path).at_least(:once).and_return('stylesheets\something\monkey\kerb-large.jpg')
      
      @file.send(:save)
      
      @file.url.should == "http://ape.com/stylesheets/something/monkey/kerb.jpg"
      @file.to_s.should == "http://ape.com/stylesheets/something/monkey/kerb.jpg"
      @file.thumb.url.should == "http://ape.com/stylesheets/something/monkey/kerb-thumb.jpg"
      @file.large.url.should == "http://ape.com/stylesheets/something/monkey/kerb-large.jpg"
    end
  end
  
  describe "An UploadedFile with a web_root set" do
    it "should return the correct URL" do
      @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, :donkey, :web_root => '/ape', :versions => [:thumb, :large])
      @file.send(:save)
      
      @file.url.should == "/ape/donkey/kerb.jpg"
      @file.to_s.should == "/ape/donkey/kerb.jpg"
      @file.thumb.url.should == "/ape/donkey/kerb-thumb.jpg"
      @file.large.url.should == "/ape/donkey/kerb-large.jpg"
    end
  end
  
  describe "the temp_value of an UploadedFile without an original filename" do
    
    setup do
      @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, :donkey)
      @file.should_receive(:original_filename).and_return(nil)
    end
    
    it "should match the TempValueRegexp" do
      @file.temp_value.should match(::UploadColumn::TempValueRegexp)
    end
    
    it "should end in the filename" do
      @file.temp_value.should match(/\/kerb\.jpg$/)
    end
  end
  
  describe "the temp_value of an UploadedFile with a different orignal filename" do
    
    setup do
      @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), nil, :donkey)
      @file.should_receive(:original_filename).at_least(:once).and_return('monkey.png')
    end
    
    it "should match the TempValueRegexp" do
      @file.temp_value.should match(::UploadColumn::TempValueRegexp)
    end
    
    it "should append the original_filename" do
      @file.temp_value.should match(/kerb\.jpg;monkey\.png$/)
    end
  end
  
  describe "the temp_value of a retrieved temporary UploadedFile" do
    
    setup do
      @file = UploadColumn::UploadedFile.retrieve_temp('12345.1234.12345/kerb.jpg', nil, :donkey)
      @file.should_receive(:original_filename).at_least(:once).and_return(nil)
    end
    
    it "should be mainatained" do
      @file.temp_value.should == '12345.1234.12345/kerb.jpg'
    end
  end
end
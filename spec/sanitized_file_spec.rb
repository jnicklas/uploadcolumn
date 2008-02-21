require File.join(File.dirname(__FILE__), 'spec_helper')
require File.join(File.dirname(__FILE__), '../lib/upload_column/sanitized_file')
begin
  require 'mime/types'
rescue LoadError
end

describe "creating a new SanitizedFile" do
  it "should yield an empty file on empty String, nil, empty StringIO" do
    UploadColumn::SanitizedFile.new("").should be_empty
    UploadColumn::SanitizedFile.new(StringIO.new("")).should be_empty
    UploadColumn::SanitizedFile.new(nil).should be_empty
    file = mock('emptyfile')
    file.should_receive(:size).at_least(:once).and_return(0)
    UploadColumn::SanitizedFile.new(file).should be_empty
  end

  it "should yield a non empty file" do
    UploadColumn::SanitizedFile.new(stub_stringio('kerb.jpg', 'image/jpeg')).should_not be_empty
    UploadColumn::SanitizedFile.new(stub_file('kerb.jpg', 'image/jpeg')).should_not be_empty
  end

  it "should not change a valid filename" do
    t = UploadColumn::SanitizedFile.new(stub_file('kerb.jpg', nil, "test.jpg"))
    t.filename.should == "test.jpg"
  end
  
  it "should remove illegal characters from a filename" do
    t = UploadColumn::SanitizedFile.new(stub_file('kerb.jpg', nil, "test-s,%&m#st?.jpg"))
    t.filename.should == "test-s___m_st_.jpg"
  end
  
  it "should remove slashes from the filename" do
    t = UploadColumn::SanitizedFile.new(stub_file('kerb.jpg', nil, "../../very_tricky/foo.bar"))
    t.filename.should_not =~ /[\\\/]/
  end
  
  it "should remove illegal characters if there is no extension" do
    t = UploadColumn::SanitizedFile.new(stub_file('kerb.jpg', nil, '`*foo'))
    t.filename.should == "__foo"
  end
  
  it "should remove the path prefix on Windows" do
    t = UploadColumn::SanitizedFile.new(stub_file('kerb.jpg', nil, 'c:\temp\foo.txt'))
    t.filename.should == "foo.txt"
  end
  
  it "should make sure the *nix directory thingies can't be used as filenames" do
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
    running { @file.copy_to(public_path('gurr.jpg')) }.should_not change(@file, :path)
  end
  
  it "should not have changed its filename when copied" do
    running { @file.copy_to(public_path('gurr.jpg')) }.should_not change(@file, :filename)
  end
  
  it "should return an object of the same class when copied" do
    new_file = @file.copy_to(public_path('gurr.jpg'))
    new_file.should be_an_instance_of(@file.class)
  end
  
  it "should adjust the path of the object that is returned when copied" do
    new_file = @file.copy_to(public_path('gurr.jpg'))
    new_file.path.should match_path(public_path('gurr.jpg'))
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
    @tempfile = stub_tempfile('kerb.jpg', 'image/jpeg')
    @file = UploadColumn::SanitizedFile.new(@tempfile)
  end

  it_should_behave_like "all sanitized files"
  
  it "should not raise an error when moved to its own location" do
    running { @file.move_to(@file.path) }.should_not raise_error
  end
  
  it "should return a new instance when copied to its own location" do
    running {
      new_file = @file.copy_to(@file.path)
      new_file.should be_an_instance_of(@file.class)
    }.should_not raise_error
  end
  
  it "should exist" do
    @file.should be_in_existence
  end

  it "should return the correct path" do
    @file.path.should_not == nil
    @file.path.should == @tempfile.path
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
  
  it "should not raise an error when moved to its own location" do
    running { @file.move_to(@file.path) }.should_not raise_error
  end
  
  it "should return a new instance when copied to its own location" do
    running {
      new_file = @file.copy_to(@file.path)
      new_file.should be_an_instance_of(@file.class)
    }.should_not raise_error
  end
  
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
  
  it "should not raise an error when moved to its own location" do
    running { @file.move_to(@file.path) }.should_not raise_error
  end
  
  it "should return a new instance when copied to its own location" do
    running {
      new_file = @file.copy_to(@file.path)
      new_file.should be_an_instance_of(@file.class)
    }.should_not raise_error
  end
  
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
  end

  # TODO: refactor this test so it mocks out system_call
  it "should be determined via *nix exec" do

    @sanitized = UploadColumn::SanitizedFile.new(@file, :get_content_type_from_file_exec => true)

    @sanitized.stub!(:path).and_return('/path/to/file.jpg')
    @sanitized.should_receive(:system_call).with(%(file -bi "/path/to/file.jpg")).and_return('text/monkey')

    @sanitized.content_type.should == "text/monkey"
  end
  
  it "shouldn't choke up when the *nix exec errors out" do
    @sanitized = UploadColumn::SanitizedFile.new(@file, :get_content_type_from_file_exec => true)
    
    lambda {
      @sanitized.should_receive(:system_call).and_raise('monkey')
      @sanitized.content_type
    }.should_not raise_error
  end

  it "should otherwise be loaded from MIME::Types" do
    if defined?(MIME::Types)
      @sanitized = UploadColumn::SanitizedFile.new(@file)
      
      @sanitized.should_receive(:get_content_type_from_exec).and_return(nil) # Make sure the *nix exec isn't interfering
      @sanitized.content_type.should == "text/css"
    else
      puts "WARNING: Could not run all examples because MIME::Types is not defined, try installing the mime-types gem!"
    end
  end

  it "should be taken from the browser if all else fails" do
    @sanitized = UploadColumn::SanitizedFile.new(@file)
    
    @file.should_receive(:content_type).at_least(:once).and_return('application/xhtml+xml') # Set up browser behavior
    # FIXME: this is brittle. There really should be another way of changing this behaviour.
    @sanitized.should_receive(:get_content_type_from_mime_types).and_return(nil) # Make sure MIME::Types isn't interfering
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
    
    #t.content_type.should == "image/css" FIXME: the result of this is upredictable and
    # differs, depending on whether or not the user has MIME::Types installed
    t.extension.should == "css"
    t.filename.should == "kerb.css"
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

describe "copying a sanitized file by path with permissions set" do
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

describe "moving a sanitized file by path with permissions set" do
  before do
    @file = UploadColumn::SanitizedFile.new(file_path('kerb.jpg'), :permissions => 0755)
    @file.move_to(public_path('gurr.jpg'))
  end
  
  it "should set the right permissions" do
    @file.should have_permissions(0755)
  end
end
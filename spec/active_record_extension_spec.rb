require File.join(File.dirname(__FILE__), 'spec_helper')

gem 'activerecord'
require 'active_record'

require File.join(File.dirname(__FILE__), '../lib/upload_column')

class Entry < ActiveRecord::Base; end # setup a basic AR class for testing

describe "an ActiveRecord class" do
  
  include UploadColumnSpecHelper
  
  it "should respond to upload_column" do
    Entry.should respond_to(:upload_column)
  end
  
  it "should reflect on upload_columns" do
    Entry.send(:reset_upload_columns)
    
    Entry.upload_column(:avatar)
    
    Entry.reflect_on_upload_columns[:avatar].should be_an_instance_of(UploadColumn::Column)
    Entry.reflect_on_upload_columns[:monkey].should == nil
    
    Entry.upload_column(:monkey)
    
    Entry.reflect_on_upload_columns[:avatar].should be_an_instance_of(UploadColumn::Column)
    Entry.reflect_on_upload_columns[:monkey].should be_an_instance_of(UploadColumn::Column)
  end
  
  it "should reset upload columns" do
    Entry.upload_column(:avatar)
    
    Entry.reflect_on_upload_columns[:avatar].should be_an_instance_of(UploadColumn::Column)
    
    Entry.send(:reset_upload_columns)
    
    Entry.reflect_on_upload_columns[:avatar].should == nil
  end
  
end

describe "an Active Record class with an upload_column" do
  
  include UploadColumnSpecHelper
  
  it "should add accessor methods" do
    # use a name that hasn't been used before! 
    entry = disconnected_model(Entry)
    entry.should_not respond_to(:llama)
    entry.should_not respond_to(:llama_temp)
    entry.should_not respond_to(:llama=)
    entry.should_not respond_to(:llama_temp=)        
    
    Entry.upload_column(:llama)
    
    entry = disconnected_model(Entry)
    
    entry.should respond_to(:llama)
    entry.should respond_to(:llama_temp)
    entry.should respond_to(:llama=)
    entry.should respond_to(:llama_temp=)
  end
  
  it "should save the name of the column to be reflected upon" do
    Entry.upload_column(:walruss)
    Entry.reflect_on_upload_columns[:walruss].name.should == :walruss
  end
  
  it "should save the options to be reflected upon" do
    options = { :donkey => true }
    
    Entry.upload_column(:walruss, options)
    
    Entry.reflect_on_upload_columns[:walruss].options.should == options
  end
end

describe "an Active Record with no upload_column" do
  
  before(:all) do
    class Monkey < ActiveRecord::Base; end
  end
  
  it "should have no uploads_column" do
    Monkey.reflect_on_upload_columns.should == {}
  end
  
  it "should be instantiable" do
    Monkey.stub!(:columns).and_return([])
    Monkey.new
  end
  
end

describe "uploading a file" do
  
  include UploadColumnSpecHelper
  
  before do
    setup_standard_mocking
    UploadColumn::UploadedFile.should_receive(:upload).with(@file, @entry, :avatar, @options).and_return(@uploaded_file)
  end
  
  it "should pass it to UploadedFile and remember it" do
    @entry.avatar.should == nil
    @entry.avatar = @file
    @entry.avatar.should == @uploaded_file
  end
  
  it "should set the attribute on the ActiveRecord" do
    @entry.should_receive(:[]=).with(:avatar, 'monkey.png')
    @entry.avatar = @file
  end
  
end

describe "uploading an empty String" do
  
  include UploadColumnSpecHelper
  
  before do
    setup_standard_mocking
  end
  
  it "should do nothing" do
    UploadColumn::UploadedFile.should_receive(:upload).with("", @entry, :avatar, @options).and_return(nil)
    @entry.avatar.should == nil
    @entry.avatar = ""
    @entry.avatar.should == nil
  end
  
  it "shouldn't affect an already uploaded file" do
    UploadColumn::UploadedFile.should_receive(:upload).with(@file, @entry, :avatar, @options).and_return(@uploaded_file)
    @entry.avatar = @file
    @entry.avatar.should == @uploaded_file

    UploadColumn::UploadedFile.should_receive(:upload).with("", @entry, :avatar, @options).and_return(nil)
    @entry.avatar = ""
    @entry.avatar.should == @uploaded_file
  end
  
end

describe "setting nil explicitly" do
  
  include UploadColumnSpecHelper
  
  before do
    setup_standard_mocking
  end
  
  it "should reset the column" do
    UploadColumn::UploadedFile.should_receive(:upload).with(@file, @entry, :avatar, @options).and_return(@uploaded_file)
    @entry.avatar = @file
    @entry.avatar.should == @uploaded_file

    @entry.avatar = nil
    @entry.avatar.should == nil
  end
end

describe "an upload_column with a value stored in the database and no uploaded_file" do
  
  include UploadColumnSpecHelper
  
  before do
    @options = mock('options', :null_object => true)
    Entry.upload_column(:avatar, @options)
    
    @entry = disconnected_model(Entry)
    @entry.stub!(:inspect).and_return('<#Entry>')
    @string = mock('some string')
    @entry.should_receive(:[]).with(:avatar).at_least(:once).and_return(@string)
  end
  
  it "should retrieve the file from the database" do
    uploaded_file = mock('uploaded file')
    
    UploadColumn::UploadedFile.should_receive(:retrieve).with(@string, @entry, :avatar, @options).and_return(uploaded_file)
    
    @entry.avatar.should == uploaded_file
  end
end

describe "saving uploaded files" do
  
  include UploadColumnSpecHelper
  
  before do
    setup_standard_mocking
  end
  
  it "should call save on the uploaded file if they are temporary files" do
    UploadColumn::UploadedFile.should_receive(:upload).with(@file, @entry, :avatar, @options).and_return(@uploaded_file)
    
    @uploaded_file.should_receive(:tempfile?).and_return(true)
    @uploaded_file.should_receive(:save)
    @entry.avatar = @file
    
    @entry.send(:save_uploaded_files)
  end
  
  it "should not call save on the uploaded file if they are not temporary files" do
    UploadColumn::UploadedFile.should_receive(:upload).with(@file, @entry, :avatar, @options).and_return(@uploaded_file)
    
    @uploaded_file.should_receive(:tempfile?).and_return(false)
    @uploaded_file.should_not_receive(:save)
    @entry.avatar = @file
    
    @entry.send(:save_uploaded_files)
  end
  
  it "should happen automatically" do
    # TODO: hmmm, how to test this? do we have to rely on an integration test?
    #@entry.should_receive(:save_uploaded_files)
    #@entry.save
  end
  
end

describe "fetching a temp value" do
  
  include UploadColumnSpecHelper
  
  setup do
    setup_standard_mocking
    
    UploadColumn::UploadedFile.should_receive(:upload).with(@file, @entry, :avatar, @options).and_return(@uploaded_file)
    
    @temp_value = '12345.1234.12345/somewhere.png'
    
    @uploaded_file.should_receive(:temp_value).and_return(@temp_value)
    @entry.avatar = @file
  end
  
  it "should fetch the value from the uploaded file" do
    @entry.avatar_temp.should == @temp_value
  end
  
end

describe "assigning a tempfile" do
  
  include UploadColumnSpecHelper
  
  setup do
    setup_standard_mocking
  end
  
  it "should not override a new file" do
    UploadColumn::UploadedFile.should_receive(:upload).with(@file, @entry, :avatar, @options).and_return(@uploaded_file)
    @uploaded_file.stub!(:new_file?).and_return(true)
    @entry.avatar = @file
    
    temp_value = '12345.1234.12345/somewhere.png'
    
    UploadColumn::UploadedFile.should_not_receive(:retrieve_temp)
    @entry.avatar_temp = temp_value
    
    @entry.avatar.should == @uploaded_file
  end
  
  it "should override a file that is not new" do
    UploadColumn::UploadedFile.should_receive(:upload).with(@file, @entry, :avatar, @options).and_return(@uploaded_file)
    @uploaded_file.stub!(:new_file?).and_return(false)
    @entry.avatar = @file
    
    temp_value = '12345.1234.12345/somewhere.png'
    
    retrieved_file = mock('a retrieved file')
    retrieved_file.should_receive(:actual_filename).and_return('walruss.png')
    UploadColumn::UploadedFile.should_receive(:retrieve_temp).with(temp_value, @entry, :avatar, @options).and_return(retrieved_file)
    @entry.should_receive(:[]=).with(:avatar, 'walruss.png')
    
    @entry.avatar_temp = temp_value
    
    @entry.avatar.should == retrieved_file
  end
  
  it "should set the file if there is none" do
    
    temp_value = '12345.1234.12345/somewhere.png'
    
    retrieved_file = mock('a retrieved file')
    retrieved_file.should_receive(:actual_filename).and_return('walruss.png')
    UploadColumn::UploadedFile.should_receive(:retrieve_temp).with(temp_value, @entry, :avatar, @options).and_return(retrieved_file)
    @entry.should_receive(:[]=).with(:avatar, 'walruss.png')
    
    @entry.avatar_temp = temp_value
    
    @entry.avatar.should == retrieved_file
  end
  
end

describe "assigning nil to temp" do
  
  include UploadColumnSpecHelper
  
  before(:each) do
    setup_standard_mocking
  end
  
  it "should do nothing" do
    UploadColumn::UploadedFile.stub!(:upload).and_return(@uploaded_file)
    @uploaded_file.stub!(:new_file?).and_return(false)
    @entry.avatar = @file
    
    UploadColumn::UploadedFile.should_not_receive(:retrieve_temp)
    @entry.should_not_receive(:[]=)
    
    lambda {
      @entry.avatar_temp = nil
    }.should_not change(@entry, :avatar)
  end
end

describe "assigning a blank string to temp" do
  
  include UploadColumnSpecHelper
  
  before(:each) do
    setup_standard_mocking
  end
  
  it "should do nothing" do
    UploadColumn::UploadedFile.should_receive(:upload).with(@file, @entry, :avatar, @options).and_return(@uploaded_file)
    @uploaded_file.stub!(:new_file?).and_return(false)
    @entry.avatar = @file
    
    UploadColumn::UploadedFile.should_not_receive(:retrieve_temp)
    @entry.should_not_receive(:[]=)
    
    lambda {
      @entry.avatar_temp = ""
    }.should_not change(@entry, :avatar)
  end
end

describe "an upload column with no file" do
  
  include UploadColumnSpecHelper
  
  before(:each) do
    setup_standard_mocking
  end
  
  it "should return no value" do
    @entry.avatar.should be_nil
  end
  
  it "should return no temp_value" do
    @entry.avatar_temp.should be_nil
  end
  
  it "should return nothing in the _public_path method" do
    @entry.avatar_public_path.should == nil
  end
  
  it "should return nothing in the _path method" do
    @entry.avatar_path.should == nil
  end
end

describe "an upload column with an uploaded file" do

  include UploadColumnSpecHelper

  before(:each) do
    setup_standard_mocking
    UploadColumn::UploadedFile.stub!(:upload).and_return(@uploaded_file)
    @entry.avatar = @file
  end
  
  it "should delegate the _public_path method to the column" do
    @uploaded_file.should_receive(:public_path).and_return('/url/to/file.exe')
    @entry.avatar_public_path.should == '/url/to/file.exe'
  end
  
  it "should delegate the _path method to the column" do
    @uploaded_file.should_receive(:path).and_return('/path/to/file.exe')
    @entry.avatar_path.should == '/path/to/file.exe'
  end
  
end

describe "an upload column with different versions and no uploaded file" do

  include UploadColumnSpecHelper

  before(:each) do
    setup_version_mocking # sets up a column with thumb and large versions
  end
  
  it "should return nil for the _thumb method" do
    @entry.avatar_thumb.should == nil
  end
  
  it "should return nil for the _large method" do
    @entry.avatar_large.should == nil
  end
  
  it "should return nil for the _thumb_url method" do
    @entry.avatar_thumb_public_path.should == nil
  end
  
  it "should return nil for the _large_path method" do
    @entry.avatar_large_path.should == nil
  end
    
end

describe "an upload column with different versions and an uploaded file" do

  include UploadColumnSpecHelper

  before(:each) do
    setup_version_mocking # sets up a column with thumb and large versions
    UploadColumn::UploadedFile.stub!(:upload).and_return(@uploaded_file)
    @entry.avatar = @file
  end
  
  it "should delegate the _thumb method to the column" do
    thumb = mock('thumb')
    @uploaded_file.should_receive(:thumb).and_return(thumb)
    @entry.avatar_thumb.should == thumb
  end
  
  it "should delegate the _large method to the column" do
    large = mock('large')
    @uploaded_file.should_receive(:large).and_return(large)
    @entry.avatar_large.should == large
  end
  
  it "should delegate the _thumb_url method to the column" do
    thumb = mock('thumb')
    thumb.should_receive(:public_path).and_return('/url/to/file.exe')
    @uploaded_file.should_receive(:thumb).and_return(thumb)
    
    @entry.avatar_thumb_public_path.should == '/url/to/file.exe'
  end
  
  it "should delegate the _large_path method to the column" do
    large = mock('large')
    large.should_receive(:path).and_return('/path/to/file.exe')
    @uploaded_file.should_receive(:large).and_return(large)
    
    @entry.avatar_large_path.should == '/path/to/file.exe'
  end
    
end

describe "uploading a file that fails an integrity check" do
  
  include UploadColumnSpecHelper
  
  before(:all) do
    Entry.validates_integrity_of :avatar
  end
  
  before(:each) do
    setup_standard_mocking
  end
  
  it "should set the column to nil" do
    UploadColumn::UploadedFile.should_receive(:upload).and_raise(UploadColumn::IntegrityError.new('something'))
    @entry.avatar = @file
    
    @entry.avatar.should be_nil
  end
  
  it "should fail an integrity validation" do
    UploadColumn::UploadedFile.should_receive(:upload).and_raise(UploadColumn::IntegrityError.new('something'))
    @entry.avatar = @file
    
    @entry.should_not be_valid
    @entry.errors.on(:avatar).should == 'something'
  end
end

describe UploadColumn::ActiveRecordExtension::ClassMethods, ".image_column" do
  
  include UploadColumnSpecHelper
  
  before(:each) do
    @class = Class.new(ActiveRecord::Base)
    @class.send(:include, UploadColumn)
  end
  
  it "should call an upload column with some specialized options" do
    @class.should_receive(:upload_column).with(:sicada,
      :manipulator => UploadColumn::Manipulators::RMagick,
      :root_dir => File.join(RAILS_ROOT, 'public', 'images'),
      :web_root => '/images',
      :monkey => 'blah',
      :extensions => UploadColumn.image_extensions
    )
    @class.image_column(:sicada, :monkey => 'blah')
  end
end

describe UploadColumn::ActiveRecordExtension::ClassMethods, ".validate_integrity" do
  
  include UploadColumnSpecHelper
  
  it "should change the options for this upload_column" do
    Entry.upload_column :avatar
    Entry.reflect_on_upload_columns[:avatar].options[:validate_integrity].should be_nil
    Entry.validates_integrity_of :avatar
    Entry.reflect_on_upload_columns[:avatar].options[:validate_integrity].should == true
  end
end
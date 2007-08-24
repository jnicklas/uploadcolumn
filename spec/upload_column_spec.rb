require File.join(File.dirname(__FILE__), 'spec_helper')
require File.join(File.dirname(__FILE__), '../lib/upload_column/sanitized_file')
require File.join(File.dirname(__FILE__), '../lib/upload_column/uploaded_file')
require File.join(File.dirname(__FILE__), '../lib/upload_column/upload_column')

gem 'activerecord'
require 'active_record'

ActiveRecord::Base.send(:include, UploadColumn)

def disconnected_model(model_class)
  model_class.stub!(:columns).and_return([])
  return model_class.new
end

def setup_standard_mocking
  @options = mock('options')
  Entry.upload_column :avatar, @options
  @entry = disconnected_model(Entry)
  
  @file = mock('file')
  
  @uploaded_file = mock('uploaded_file')
  @uploaded_file.stub!(:filename).and_return('monkey.png')
end

class Entry < ActiveRecord::Base; end # setup a basic AR class for testing

describe "an ActiveRecord class" do
  
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

describe "declaring an upload_column" do
  
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
  
  it "should save the name to be reflected upon" do
    Entry.upload_column(:walruss)
    Entry.reflect_on_upload_columns[:walruss].name.should == :walruss
  end
  
  it "should save the options to be reflected upon" do
    options = mock('options', :null_object => true)
    Entry.upload_column(:walruss, options)
    Entry.reflect_on_upload_columns[:walruss].options.should == options
  end
end

describe "uploading a file" do
  
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
  before do
    @options = mock('options')
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
  
  setup do
    setup_standard_mocking
    
    UploadColumn::UploadedFile.should_receive(:upload).with(@file, @entry, :avatar, @options).and_return(@uploaded_file)
    
    @temp_value = mock('temp_value')
    
    @uploaded_file.should_receive(:temp_value).and_return(@temp_value)
    @entry.avatar = @file
  end
  
  it "should fetch the value from the uploaded file" do
    @entry.avatar_temp.should == @temp_value
  end
  
end

describe "an UploadColumn with a new file" do
  
  setup do
    setup_standard_mocking
    
    UploadColumn::UploadedFile.should_receive(:upload).with(@file, @entry, :avatar, @options).and_return(@uploaded_file)
    @uploaded_file.stub!(:new_file?).and_return(true)
    @entry.avatar = @file
  end
  
  it "should not be overriden by assiging a tempfile" do
    
    temp_value = mock('temp value')
    UploadColumn::UploadedFile.should_not_receive(:retrieve_temp)
    @entry.avatar_temp = temp_value
    
    @entry.avatar.should == @uploaded_file
  end
end

describe "an UploadColumn with a file that is not new" do

  setup do
    setup_standard_mocking
    
    UploadColumn::UploadedFile.should_receive(:upload).with(@file, @entry, :avatar, @options).and_return(@uploaded_file)
    @uploaded_file.stub!(:new_file?).and_return(false)
    @entry.avatar = @file
  end
  
  it "should be overriden by a tempfile" do
    temp_value = mock('temp value')
    retrieved_file = mock('a retrieved file')
    retrieved_file.should_receive(:filename).and_return('walruss.png')
    UploadColumn::UploadedFile.should_receive(:retrieve_temp).with(temp_value, @entry, :avatar, @options).and_return(retrieved_file)
    @entry.should_receive(:[]=).with(:avatar, 'walruss.png')
    
    @entry.avatar_temp = temp_value
    
    @entry.avatar.should == retrieved_file
  end
  
end

describe "an UploadColumn with no file" do
  
  setup do
    setup_standard_mocking
  end
  
  it "should assign a tempfile" do
    
    temp_value = mock('temp value')
    retrieved_file = mock('a retrieved file')
    retrieved_file.should_receive(:filename).and_return('walruss.png')
    UploadColumn::UploadedFile.should_receive(:retrieve_temp).with(temp_value, @entry, :avatar, @options).and_return(retrieved_file)
    @entry.should_receive(:[]=).with(:avatar, 'walruss.png')
    
    @entry.avatar_temp = temp_value
    
    @entry.avatar.should == retrieved_file
  end
  
  it "should return no temp_value" do
    @entry.avatar_temp.should === nil
  end
  
end




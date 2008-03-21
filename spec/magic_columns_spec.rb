require File.join(File.dirname(__FILE__), 'spec_helper')

gem 'activerecord'
require 'active_record'

require File.join(File.dirname(__FILE__), '../lib/upload_column')

ActiveRecord::Base.send(:include, UploadColumn)

class Entry < ActiveRecord::Base; end # setup a basic AR class for testing

describe "UploadColumn::MagicColumns.set_upload_column_with_magic_columns" do
  
  include UploadColumnSpecHelper
  
  before(:each) do
    setup_standard_mocking
    UploadColumn::UploadedFile.should_receive(:upload).with(@file, @entry, :avatar, @options).and_return(@uploaded_file)
  end
  
  it "should assign methods from the uploaded file to database columns" do
    Entry.should_receive(:column_names).and_return([ 'monkey', 'llama', 'avatar_path', 'avatar_size'])
    
    @uploaded_file.stub!(:path).and_return('/path/to/my/file')
    @uploaded_file.stub!(:size).and_return(9999)
    
    @entry.avatar = @file

    @entry.avatar_path.should == '/path/to/my/file'
    @entry.avatar_size.should == 9999
  end
  
  it "should do nothing when the column names do not exist on the object" do
    Entry.should_receive(:column_names).and_return([ 'monkey', 'llama', 'avatar_monkey', 'avatar_size'])
    
    @uploaded_file.stub!(:size).and_return(9999)
    
    @entry.avatar = @file
    
    @entry.avatar_monkey.should be_nil
    @entry.avatar_size.should == 9999
  end
end

describe "UploadColumn::MagicColumns.set_upload_column_temp_with_magic_columns" do
  
  include UploadColumnSpecHelper
  
  before(:each) do
    setup_standard_mocking
    
    @temp_value = '12345.1234.12345/somewhere.png'
    
    @retrieved_file = mock('a retrieved file')
    @retrieved_file.should_receive(:actual_filename).and_return('walruss.png')
    
    UploadColumn::UploadedFile.should_receive(:retrieve_temp).with(@temp_value, @entry, :avatar, @options).and_return(@retrieved_file)
    @entry.should_receive(:[]=).with(:avatar, 'walruss.png')
  end
  
  it "should assign methods from the uploaded file to database columns" do
    Entry.stub!(:column_names).and_return([ 'monkey', 'llama', 'avatar_path', 'avatar_size'])
    
    @retrieved_file.stub!(:path).and_return('/path/to/my/file')
    @retrieved_file.stub!(:size).and_return(9999)
    
    @entry.avatar_temp = @temp_value
    
    @entry.avatar_path.should == '/path/to/my/file'
    @entry.avatar_size.should == 9999
  end
  
  it "should do nothing when the column names do not exist on the object" do
    Entry.stub!(:column_names).and_return([ 'monkey', 'llama', 'avatar_monkey', 'avatar_size'])
    
    @retrieved_file.stub!(:size).and_return(9999)
    
    @entry.avatar_temp = @temp_value
    
    @entry.avatar_monkey.should be_nil
    @entry.avatar_size.should == 9999
  end
end

describe "UploadColumn::MagicColumns.save_uploaded_files_with_magic_columns" do
  
  include UploadColumnSpecHelper
  
  before(:each) do
    setup_standard_mocking
    UploadColumn::UploadedFile.should_receive(:upload).with(@file, @entry, :avatar, @options).and_return(@uploaded_file)
    @entry.avatar = @file
    @uploaded_file.stub!(:tempfile?).and_return(false)
  end
  
  it "should reevaluate magic columns" do
    Entry.stub!(:column_names).and_return([ 'monkey', 'llama', 'avatar_path', 'avatar_size'])
    
    @uploaded_file.stub!(:path).and_return('/path/to/my/file')
    @uploaded_file.stub!(:size).and_return(9999)
    
    @entry.send(:save_uploaded_files)
    
    @entry.avatar_path.should == '/path/to/my/file'
    @entry.avatar_size.should == 9999
  end
  
  it "should do nothing when the column names do not exist on the object" do
    Entry.stub!(:column_names).and_return([ 'monkey', 'llama', 'avatar_monkey', 'avatar_size'])
    
    @uploaded_file.stub!(:size).and_return(9999)
    
    @entry.send(:save_uploaded_files)
    
    @entry.avatar_monkey.should be_nil
    @entry.avatar_size.should == 9999
  end
  
end


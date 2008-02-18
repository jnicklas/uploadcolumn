require File.join(File.dirname(__FILE__), 'spec_helper')

gem 'activerecord'
require 'active_record'

require File.join(File.dirname(__FILE__), '../lib/upload_column')

describe "UploadColumn" do
  
  it "should have a default configuration" do
    UploadColumn.configuration.should be_an_instance_of(Hash)
    config = UploadColumn.configuration
    
    config[:tmp_dir].should == 'tmp'
    config[:store_dir].should be_an_instance_of(Proc)
    config[:root_dir].should == File.join(RAILS_ROOT, 'public')
    config[:get_content_type_from_file_exec].should == true
    config[:fix_file_extensions].should == false
    config[:process].should == nil
    config[:permissions].should == 0644
    config[:extensions].should == UploadColumn.extensions
    config[:web_root].should == ''
    config[:manipulator].should == nil
    config[:versions].should == nil
    config[:validate_integrity].should == false
  end
  
  it "should have a list of allowed extensions" do
    UploadColumn.extensions.should == %w(asf ai avi doc dvi dwg eps gif gz jpg jpeg mov mp3 mpeg odf pac pdf png ppt psd swf swx tar tar.gz torrent txt wmv wav xls zip)
  end
  
  it "should have a list of allowed image extensions" do
    UploadColumn.image_extensions.should == %w(jpg jpeg gif png)
  end
  
end

describe "UploadColumn.configure" do
  
  after do
    UploadColumn.reset_configuration
  end
  
  it "should yield a configuration proxy" do
    UploadColumn.configure do |config|
      config.should be_an_instance_of(UploadColumn::ConfigurationProxy)
    end
  end
  
  it "should change the configuration of a known option" do
    UploadColumn.configure do |config|
      config.web_root = "/monkey"
    end
    
    UploadColumn.configuration[:web_root].should == "/monkey"
  end
  
  it "should change the configuration of an unknown option" do
    UploadColumn.configure do |config|
      config.monkey = ":)"
    end
    
    UploadColumn.configuration[:monkey].should == ":)"
  end
end
require File.join(File.dirname(__FILE__), 'spec_helper')

require 'active_record'

require File.join(File.dirname(__FILE__), '../lib/upload_column')

ActiveRecord::Base.send(:include, UploadColumn)

describe "uploading a file" do
  it "should trigger an _after_upload callback" do
    record = mock('a record')
    record.should_receive(:avatar_after_upload)
    @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), record, :avatar)
  end
end

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

describe "an UploadedFile where filename is a String" do
  before do
    @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), nil, nil, :filename => 'monkey.png', :versions => [:thumb, :large])
  end
  
  it "should have the correct filename" do
    @file.filename.should == 'monkey.png'
  end
  
  it "should remember the actual filename" do
    @file.actual_filename.should == "kerb.jpg"
  end
  
  it "should have versions with the correct filename" do
    @file.thumb.filename.should == 'monkey.png'
    @file.large.filename.should == 'monkey.png'
  end
end

describe "an UploadedFile where filename is a Proc with the record piped in" do
  before do
    record = mock('a record')
    record.stub!(:name).and_return('quack')
    @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), record, nil, :versions => [:thumb, :large], :filename => proc{ |r| r.name })
  end
  
  it "should have the correct filename" do
    @file.filename.should == 'quack'
  end
  
  it "should remember the actual filename" do
    @file.actual_filename.should == "kerb.jpg"
  end
  
  it "should have versions with the correct filename" do
    @file.thumb.filename.should == 'quack'
    @file.large.filename.should == 'quack'
  end
end

describe "an UploadedFile where filename is a Proc with the record and file piped in" do
  before do
    record = mock('a record')
    record.stub!(:name).and_return('quack')
    @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), record, nil, :versions => [:thumb, :large], :filename => proc{ |r, f| "#{r.name}-#{f.basename}-#{f.suffix}quox.#{f.extension}"})
  end
  
  it "should have the correct filename" do
    @file.filename.should == 'quack-kerb-quox.jpg'
  end
  
  it "should remember the actual filename" do
    @file.actual_filename.should == "kerb.jpg"
  end
  
  it "should have versions with the correct filename" do
    @file.thumb.filename.should == 'quack-kerb-thumbquox.jpg'
    @file.large.filename.should == 'quack-kerb-largequox.jpg'
  end
end

describe "an UploadedFile with a filename callback" do
  before do
    @instance = mock('instance with filename callback')
    @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), @instance, :monkey, :versions => [:thumb, :large])
  end
  
  it "should have the correct filename" do
    @instance.should_receive(:monkey_filename).with(@file).and_return("llama")
    @file.filename.should == 'llama'
  end
  
  it "should remember the actual filename" do
    @file.actual_filename.should == "kerb.jpg"
  end
  
  it "should have versions with the correct filename" do
    @instance.should_receive(:monkey_filename).with(@file.thumb).and_return("barr")
    @instance.should_receive(:monkey_filename).with(@file.large).and_return("quox")
    @file.thumb.filename.should == 'barr'
    @file.large.filename.should == 'quox'
  end
end

describe "uploading an UploadedFile where filename is a Proc" do
  before do
    record = mock('a record')
    record.stub!(:name).and_return('quack')
    @file = UploadColumn::UploadedFile.upload(stub_file('kerb.jpg'), record, nil, :versions => [:thumb, :large], :filename => proc{ |r, f| "#{r.name}-#{f.basename}-#{f.suffix}quox.#{f.extension}"})
  end
  
  it "should have the correct filename" do
    @file.filename.should == 'quack-kerb-quox.jpg'
  end
  
  it "should remember the actual filename" do
    @file.actual_filename.should == "kerb.jpg"
  end
  
  it "should have versions with the correct filename" do
    @file.thumb.filename.should == 'quack-kerb-thumbquox.jpg'
    @file.large.filename.should == 'quack-kerb-largequox.jpg'
  end
  
  it "should have a correct path" do
    @file.path.should match_path(PUBLIC, 'tmp', /(?:\d+\.)+\d+/, 'quack-kerb-quox.jpg' )
  end
  
  it "should have versions with correct paths" do
    @file.thumb.path.should match_path(PUBLIC, 'tmp', /(?:\d+\.)+\d+/, 'quack-kerb-thumbquox.jpg' )
    @file.large.path.should match_path(PUBLIC, 'tmp', /(?:\d+\.)+\d+/, 'quack-kerb-largequox.jpg' )
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
    @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), i, :monkey)
    i.should_receive(:monkey_store_dir).with(@file).and_return('llama')
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
    @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), i, :monkey)
    i.should_receive(:monkey_tmp_dir).with(@file).and_return('gorilla')
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
  
  it "should be a tempfile" do
    @file.should be_a_tempfile
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
  
  it "should not be a tempfile" do
    @file.should_not be_a_tempfile
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

describe "an UploadedFile with a manipulator and versions" do
  before do
    a_manipulator = Module.new
    a_manipulator.send(:define_method, :monkey! ) { |stuff| stuff }
    @file = UploadColumn::UploadedFile.new(:open, stub_file('kerb.jpg'), nil, :donkey, :versions => [ :thumb, :large ], :manipulator => a_manipulator)
  end
  
  it "should extend the object with the manipulator methods." do
    @file.should respond_to(:monkey!)
  end
  
  it "should extend the versions with the manipulator methods." do
    @file.thumb.should respond_to(:monkey!)
    @file.large.should respond_to(:monkey!)
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

  it "should return the basename without the version" do
    @thumb.basename.should == "kerb"
    @large.basename.should == "kerb"
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
  
  it "should not be a tempfile" do
    @file.should_not be_a_tempfile
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
  
  it "should not be a tempfile" do
    @file.should_not be_a_tempfile
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
  
  it "should  not be a tempfile" do
    @file.should_not be_a_tempfile
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
  
  it "should be a tempfile" do
    @file.should be_a_tempfile
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
  
  it "should be a tempfile" do
    @file.should be_a_tempfile
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
  
  it "should be a tempfile" do
    @file.should be_a_tempfile
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
    end.should raise_error(UploadColumn::UploadError)
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

describe "the temp_value of an UploadedFile that is not temporary" do
  
  setup do
    @file = UploadColumn::UploadedFile.retrieve('kerb.jpg', nil, :donkey)
  end
  
  it "should be mainatained" do
    @file.temp_value.should be_nil
  end
end
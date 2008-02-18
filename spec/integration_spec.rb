require File.join(File.dirname(__FILE__), 'spec_helper')

gem 'activerecord'
require 'active_record'

require File.join(File.dirname(__FILE__), '../lib/upload_column')

# change this if sqlite is unavailable
dbconfig = {
  :adapter => 'sqlite3',
  :database => 'db/test.sqlite3'
}

ActiveRecord::Base.establish_connection(dbconfig)
ActiveRecord::Migration.verbose = false

class TestMigration < ActiveRecord::Migration
  def self.up
    create_table :events, :force => true do |t|
      t.column :image, :string
      t.column :textfile, :string
    end
    
    create_table :movies, :force => true do |t|
      t.column :movie, :string
      t.column :name, :string
      t.column :description, :text
    end
  end

  def self.down
    drop_table :events
    drop_table :movies
  end
end

class MagicColumnMigration < ActiveRecord::Migration
  def self.up
    add_column :events, :image_size, :integer
    add_column :events, :image_url, :string
    add_column :events, :image_path, :string
    add_column :events, :image_monkey, :string
    Event.reset_column_information
  end
end

class Event < ActiveRecord::Base; end # setup a basic AR class for testing
class Movie < ActiveRecord::Base; end # setup a basic AR class for testing

def migrate
  before(:all) { TestMigration.up }
  after(:all) { TestMigration.down }
end

# TODO: RSpec syntax and integration really don't mix. In the long run, it would
# be nice to rewrite this stuff with the Story runner.

describe "normally instantiating and saving a record" do
  
  migrate
  
  it "shouldn't fail" do
    Event.reflect_on_upload_columns.should == {}
    running { @event = Event.new }.should_not raise_error
    @event.image = "monkey"
    running { @event.save }.should_not raise_error
  end
  
end

describe "uploading a single file" do
  
  migrate
  
  before do
    Event.upload_column(:image)
    @event = Event.new
    @event.image = stub_tempfile('kerb.jpg')
  end
  
  it "should set the correct path" do
    @event.image.path.should match_path(PUBLIC, 'tmp', /(?:\d+\.)+\d+/, 'kerb.jpg' )
  end
  
  it "should copy the file to temp." do      
    File.exists?(@event.image.path).should === true
    @event.image.path.should be_identical_with(file_path('kerb.jpg'))
  end
  
  it "should set the correct url" do
    @event.image.url.should =~ %r{/tmp/(?:\d+\.)+\d+/kerb.jpg}
  end
  
  after do
    FileUtils.rm_rf(PUBLIC)
  end
end

describe "uploading a file and then saving the record" do
  
  migrate
  
  before do
    Event.upload_column(:image)
    @event = Event.new
    @event.image = stub_tempfile('kerb.jpg')
    @event.save
  end
  
  it "should set the correct path" do
    @event.image.path.should match_path(PUBLIC, 'image', 'kerb.jpg')
  end
  
  it "should copy the file to the correct location" do
    File.exists?(@event.image.path)
    @event.image.path.should be_identical_with(file_path('kerb.jpg'))
  end
  
  it "should set the correct url" do
    @event.image.url.should == "/image/kerb.jpg"
  end
  
  it "should save the filename to the database" do
    Event.find(@event.id)['image'].should == 'kerb.jpg'
  end
  
  after do
    FileUtils.rm_rf(PUBLIC)
  end
  
end

describe "uploading a file with versions" do
  
  migrate
  
  before do
    Event.upload_column(:image, :versions => [ :thumb, :large ] )
    @event = Event.new
    @event.image = stub_tempfile('kerb.jpg')
  end
  
  it "should set the correct path" do
    @event.image.path.should match_path(PUBLIC, 'tmp', /(?:\d+\.)+\d+/, 'kerb.jpg' )
    @event.image.thumb.path.should match_path(PUBLIC, 'tmp', /(?:\d+\.)+\d+/, 'kerb-thumb.jpg' )
    @event.image.large.path.should match_path(PUBLIC, 'tmp', /(?:\d+\.)+\d+/, 'kerb-large.jpg' )
  end
  
  it "should copy the file to temp." do      
    File.exists?(@event.image.path).should === true
    File.exists?(@event.image.thumb.path).should === true
    File.exists?(@event.image.large.path).should === true
    @event.image.path.should be_identical_with(file_path('kerb.jpg'))
    @event.image.thumb.path.should be_identical_with(file_path('kerb.jpg'))
    @event.image.large.path.should be_identical_with(file_path('kerb.jpg'))
  end
  
  it "should set the correct url" do
    @event.image.url.should =~ %r{/tmp/(?:\d+\.)+\d+/kerb.jpg}
    @event.image.thumb.url.should =~ %r{/tmp/(?:\d+\.)+\d+/kerb-thumb.jpg}
    @event.image.large.url.should =~ %r{/tmp/(?:\d+\.)+\d+/kerb-large.jpg}
  end
  
  after do
    FileUtils.rm_rf(PUBLIC)
  end
  
end

describe "uploading a file with versions and then saving the record" do
  
  migrate
  
  before do
    Event.upload_column(:image, :versions => [ :thumb, :large ] )
    @event = Event.new
    @event.image = stub_tempfile('kerb.jpg')
    @event.save
  end
  
  it "should set the correct path" do
    @event.image.path.should match_path(PUBLIC, 'image', 'kerb.jpg' )
    @event.image.thumb.path.should match_path(PUBLIC, 'image', 'kerb-thumb.jpg' )
    @event.image.large.path.should match_path(PUBLIC, 'image', 'kerb-large.jpg' )
  end
  
  it "should copy the file to the correct location." do      
    File.exists?(@event.image.path).should === true
    File.exists?(@event.image.thumb.path).should === true
    File.exists?(@event.image.large.path).should === true
    @event.image.path.should be_identical_with(file_path('kerb.jpg'))
    @event.image.thumb.path.should be_identical_with(file_path('kerb.jpg'))
    @event.image.large.path.should be_identical_with(file_path('kerb.jpg'))
  end
  
  it "should set the correct url" do
    @event.image.url.should == "/image/kerb.jpg"
    @event.image.thumb.url.should == "/image/kerb-thumb.jpg"
    @event.image.large.url.should == "/image/kerb-large.jpg"
  end
  
  it "should save the filename to the database" do
    Event.find(@event.id)['image'].should == 'kerb.jpg'
  end
  
  after do
    FileUtils.rm_rf(PUBLIC)
  end
  
end


describe "assigning a file from temp with versions" do
  
  migrate
  
  before do
    Event.upload_column(:image, :versions => [ :thumb, :large ] )
    @blah = Event.new
    
    @event = Event.new

    @blah.image = stub_tempfile('kerb.jpg') # we've alredy tested this...
    
    @event.image_temp = @blah.image_temp
  end
  
  it "should set the correct path" do
    @event.image.path.should == @blah.image.path
    @event.image.thumb.path.should == @blah.image.thumb.path
    @event.image.large.path.should == @blah.image.large.path
  end
  
  it "should set the correct url" do
    @event.image.url.should == @blah.image.url
    @event.image.thumb.url.should == @blah.image.thumb.url
    @event.image.large.url.should == @blah.image.large.url
  end
  
  after do
    FileUtils.rm_rf(PUBLIC)
  end
  
end


describe "assigning a file from temp with versions and then saving the record" do
  
  migrate
  
  before do
    Event.upload_column(:image, :versions => [ :thumb, :large ] )
    @blah = Event.new
    
    @event = Event.new

    @blah.image = stub_tempfile('kerb.jpg') # we've alredy tested this...
    
    @event.image_temp = @blah.image_temp
    
    @event.save
  end
  
  it "should set the correct path" do
    @event.image.path.should match_path(PUBLIC, 'image', 'kerb.jpg' )
    @event.image.thumb.path.should match_path(PUBLIC, 'image', 'kerb-thumb.jpg' )
    @event.image.large.path.should match_path(PUBLIC, 'image', 'kerb-large.jpg' )
  end
  
  it "should copy the file to the correct location." do      
    File.exists?(@event.image.path).should === true
    File.exists?(@event.image.thumb.path).should === true
    File.exists?(@event.image.large.path).should === true
    @event.image.path.should be_identical_with(file_path('kerb.jpg'))
    @event.image.thumb.path.should be_identical_with(file_path('kerb.jpg'))
    @event.image.large.path.should be_identical_with(file_path('kerb.jpg'))
  end
  
  it "should set the correct url" do
    @event.image.url.should == "/image/kerb.jpg"
    @event.image.thumb.url.should == "/image/kerb-thumb.jpg"
    @event.image.large.url.should == "/image/kerb-large.jpg"
  end
  
  it "should save the filename to the database" do
    Event.find(@event.id)['image'].should == 'kerb.jpg'
  end
  
  after do
    FileUtils.rm_rf(PUBLIC)
  end
  
end

describe "an upload_column with an uploaded file" do
  
  migrate
  
  before do
    Event.upload_column(:image)
    @event = Event.new
    @event.image = stub_tempfile('kerb.jpg')
    @event.save
  end
  
  it "should not be overwritten by an empty String" do
    @e2 = Event.find(@event.id)
    lambda {
      @e2.image = ""
      @e2.save
    }.should_not change(@e2.image, :path)
    @e2[:image].should == "kerb.jpg"
  end
  
  it "should not be overwritten by an empty StringIO" do
    @e2 = Event.find(@event.id)
    lambda {
      @e2.image = StringIO.new('')
      @e2.save
    }.should_not change(@e2.image, :path)
    @e2[:image].should == "kerb.jpg"
  end
  
  it "should not be overwritten by an empty file" do
    @e2 = Event.find(@event.id)
    lambda {
      file = stub_file('kerb.jpg')
      file.stub!(:size).and_return(0)
      @e2.image = file
      @e2.save
    }.should_not change(@e2.image, :path)
    @e2[:image].should == "kerb.jpg"
  end
  
  it "should be overwritten by another file" do
    @e2 = Event.find(@event.id)
    lambda {
      file = stub_file('skanthak.png')
      @e2.image = file
      @e2.save
    }.should_not change(@e2.image, :path)
    @e2[:image].should == "skanthak.png"
  end
  
  it "should be marshallable" do
    running { Marshal.dump(@entry) }.should_not raise_error
  end
  
  after do
    FileUtils.rm_rf(PUBLIC)
  end
end

describe "uploading an image with several versions, the rmagick manipulator and instructions to rescale" do
  
  migrate
  
  # buuhuu so sue me. This spec runs a whole second faster if we do this before all instead of
  # before each.
  before(:all) do
    Event.upload_column(:image,
      :versions => { :thumb => 'c100x100', :large => '200x200' },
      :manipulator => UploadColumn::Manipulators::RMagick
    )
    @event = Event.new
    @event.image = stub_tempfile('kerb.jpg')
  end
  
  it "should set the correct path" do
    @event.image.path.should match_path(PUBLIC, 'tmp', /(?:\d+\.)+\d+/, 'kerb.jpg' )
    @event.image.thumb.path.should match_path(PUBLIC, 'tmp', /(?:\d+\.)+\d+/, 'kerb-thumb.jpg' )
    @event.image.large.path.should match_path(PUBLIC, 'tmp', /(?:\d+\.)+\d+/, 'kerb-large.jpg' )
  end
  
  it "should copy the files to temp." do   
    File.exists?(@event.image.path).should === true
    File.exists?(@event.image.thumb.path).should === true
    File.exists?(@event.image.large.path).should === true
  end
  
  it "should set the correct url" do
    @event.image.url.should =~ %r{/tmp/(?:\d+\.)+\d+/kerb.jpg}
    @event.image.thumb.url.should =~ %r{/tmp/(?:\d+\.)+\d+/kerb-thumb.jpg}
    @event.image.large.url.should =~ %r{/tmp/(?:\d+\.)+\d+/kerb-large.jpg}
  end
  
  it "should preserve the main file" do
    @event.image.path.should be_identical_with(file_path('kerb.jpg'))
  end
  
  it "should change the versions" do
    @event.image.thumb.path.should_not be_identical_with(file_path('kerb.jpg'))
    @event.image.large.path.should_not be_identical_with(file_path('kerb.jpg'))
  end
  
  it "should rescale the images to the correct sizes" do
    @event.image.large.should be_no_larger_than(200, 200)
    @event.image.thumb.should have_the_exact_dimensions_of(100, 100)
  end
  
  after(:all) do
    FileUtils.rm_rf(PUBLIC)
  end
end


# TODO: make image_science not crap out on my macbook
#describe "uploading an image with several versions, the image_science manipulator and instructions to rescale" do
#  
#  migrate
#  
#  # buuhuu so sue me. This spec runs a whole second faster if we do this before all instead of
#  # before each.
#  before(:all) do
#    Event.upload_column(:image,
#      :versions => { :thumb => 'c100x100', :large => '200x200' },
#      :manipulator => UploadColumn::Manipulators::ImageScience
#    )
#    @event = Event.new
#    @event.image = stub_tempfile('kerb.jpg')
#  end
#  
#  it "should set the correct path" do
#    @event.image.path.should match_path(PUBLIC, 'tmp', /(?:\d+\.)+\d+/, 'kerb.jpg' )
#    @event.image.thumb.path.should match_path(PUBLIC, 'tmp', /(?:\d+\.)+\d+/, 'kerb-thumb.jpg' )
#    @event.image.large.path.should match_path(PUBLIC, 'tmp', /(?:\d+\.)+\d+/, 'kerb-large.jpg' )
#  end
#  
#  it "should copy the files to temp." do   
#    File.exists?(@event.image.path).should === true
#    File.exists?(@event.image.thumb.path).should === true
#    File.exists?(@event.image.large.path).should === true
#  end
#  
#  it "should set the correct url" do
#    @event.image.url.should =~ %r{/tmp/(?:\d+\.)+\d+/kerb.jpg}
#    @event.image.thumb.url.should =~ %r{/tmp/(?:\d+\.)+\d+/kerb-thumb.jpg}
#    @event.image.large.url.should =~ %r{/tmp/(?:\d+\.)+\d+/kerb-large.jpg}
#  end
#  
#  it "should preserve the main file" do
#    @event.image.path.should be_identical_with(file_path('kerb.jpg'))
#  end
#  
#  it "should change the versions" do
#    @event.image.thumb.path.should_not be_identical_with(file_path('kerb.jpg'))
#    @event.image.large.path.should_not be_identical_with(file_path('kerb.jpg'))
#  end
#  
#  it "should rescale the images to the correct sizes" do
#    @event.image.large.should be_no_larger_than(200, 200)
#    @event.image.thumb.should have_the_exact_dimensions_of(100, 100)
#  end
#  
#  after(:all) do
#    FileUtils.rm_rf(PUBLIC)
#  end
#end

describe "uploading a file with an extension that is not in the whitelist" do
  
  migrate
  
  before(:each) do
    Event.upload_column(:image, :fix_file_extensions => false)
    Event.validates_integrity_of :image
    
    @event = Event.new
  end
  
  it "should add an error to the record" do
    @event.image = stub_tempfile('kerb.jpg', nil, 'monkey.exe')
    @event.should_not be_valid
    @event.errors.on(:image).should == "has an extension that is not allowed."
    @event.image.should be_nil
  end
  
  it "should be reversible by uploading a valid file" do
    
    @event.image = stub_tempfile('kerb.jpg', nil, 'monkey.exe')

    @event.should_not be_valid
    @event.errors.on(:image).should include('has an extension that is not allowed.')

    @event.image = stub_tempfile('kerb.jpg')

    @event.should be_valid
    @event.errors.on(:image).should be_nil
  end
end

describe "uploading a file with magic columns" do
  
  migrate
  
  before(:all) do
    MagicColumnMigration.up
  end
  
  before(:each) do
    @event = Event.new
    @event.image = stub_tempfile('kerb.jpg')
  end
  
  it "should automatically set the image size" do
    @event.image_size.should == @event.image.size    
  end
  
  it "should automatically set the image path" do
    @event.image_path.should == @event.image.path    
  end
  
  it "should automatically set the image url" do
    @event.image_url.should == @event.image.url    
  end
  
  it "should ignore columns whose names aren't methods on the column" do
    @event.image_monkey.should == nil
  end
end

describe "assigning a file from tmp with magic columns" do
  
  migrate
  
  before(:all) do
    MagicColumnMigration.up
  end
  
  before(:each) do
    e1 = Event.new
    e1.image = stub_tempfile('kerb.jpg')
    @event = Event.new
    @event.image_temp = e1.image_temp
  end
  
  it "should automatically set the image size" do
    @event.image_size.should == @event.image.size    
  end
  
  it "should automatically set the image path" do
    @event.image_path.should == @event.image.path    
  end
  
  it "should automatically set the image url" do
    @event.image_url.should == @event.image.url    
  end
  
  it "should ignore columns whose names aren't methods on the column" do
    @event.image_monkey.should == nil
  end
end

describe "uploading and saving a file with magic columns" do
  
  migrate
  
  before(:all) do
    MagicColumnMigration.up
  end
  
  before(:each) do
    @event = Event.new
    @event.image = stub_tempfile('kerb.jpg')
    @event.save
  end
  
  it "should automatically set the image size" do
    @event.image_size.should == @event.image.size    
  end
  
  it "should automatically set the image path" do
    @event.image_path.should == @event.image.path    
  end
  
  it "should automatically set the image url" do
    @event.image_url.should == @event.image.url    
  end
  
  it "should ignore columns whose names aren't methods on the column" do
    @event.image_monkey.should == nil
  end
end

describe "assigning a file from tmp and saving it with magic columns" do
  
  migrate
  
  before(:all) do
    MagicColumnMigration.up
  end
  
  before(:each) do
    e1 = Event.new
    e1.image = stub_tempfile('kerb.jpg')
    @event = Event.new
    @event.image_temp = e1.image_temp
    @event.save
  end
  
  it "should automatically set the image size" do
    @event.image_size.should == @event.image.size    
  end
  
  it "should automatically set the image path" do
    @event.image_path.should == @event.image.path    
  end
  
  it "should automatically set the image url" do
    @event.image_url.should == @event.image.url    
  end
  
  it "should ignore columns whose names aren't methods on the column" do
    @event.image_monkey.should == nil
  end
end
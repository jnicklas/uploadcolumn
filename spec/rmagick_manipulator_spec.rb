require File.join(File.dirname(__FILE__), 'spec_helper')
require File.join(File.dirname(__FILE__), '../lib/upload_column/manipulators/rmagick')

describe UploadColumn::Manipulators::RMagick, "#manipulate!" do
  
  before(:each) do
    @uploaded_file = class << self; self end # this is a singleton object
    @uploaded_file.extend( UploadColumn::Manipulators::RMagick )
    @uploaded_file.load_manipulator_dependencies
    @uploaded_file.stub!(:path).and_return('/some_path.png')
  end
  
  it "should yield the first frame of the image and then save the result, for a single-framed image" do
    a_frame = mock('a frame')
    Magick::Image.should_receive(:read).with('/some_path.png').and_return( [a_frame] )
    
    @uploaded_file.manipulate! do |img|
      img.should == a_frame
      img.should_receive(:write).with('/some_path.png')
      img
    end
  end
  
  it "should yield all frames and save the result, for a multi-framed image" do
    image = Magick::Image.read(file_path('netscape.gif'))
    Magick::Image.should_receive(:read).with('/some_path.png').and_return( image )
    
    imagelist = Magick::ImageList.new
    Magick::ImageList.should_receive(:new).and_return(imagelist)
    
    imagelist.should_receive(:<<).with(image[0]).exactly(:once).ordered
    imagelist.should_receive(:<<).with(image[1]).exactly(:once).ordered
    
    image[0].should_receive(:solarize)
    image[1].should_receive(:solarize)
    
    imagelist.should_receive(:write).with('/some_path.png')
    
    @uploaded_file.manipulate! do |img|
      img.solarize
      img
    end
    
  end
  
  it "should raise an more meaningful error if something goes wrong" do
    Magick::Image.should_receive(:read).and_raise(Magick::ImageMagickError.new('arrggh'))
    
    lambda do
      @uploaded_file.manipulate! do |img|
        img
      end      
    end.should raise_error( UploadColumn::ManipulationError, "Failed to manipulate with rmagick, maybe it is not an image? Original Error: arrggh" )

  end
  
end

describe UploadColumn::Manipulators::RMagick, "#resize!" do

  before(:each) do
    @uploaded_file = class << self; self end
    @uploaded_file.extend( UploadColumn::Manipulators::RMagick )
    @uploaded_file.load_manipulator_dependencies
    @uploaded_file.stub!(:path).and_return('/some_path.png')
  end

  it "should use rmagick to resize the image to the appropriate size" do
    
    img = mock('an image frame')
    @uploaded_file.should_receive(:manipulate!).and_yield(img)
    
    geometry_img = mock('image returned by change_geometry')
    
    img.should_receive(:change_geometry).with("200x200").and_yield(20, 40, geometry_img)
    
    geometry_img.should_receive(:resize).with(20, 40)
    
    @uploaded_file.resize!("200x200")
  end

end


describe UploadColumn::Manipulators::RMagick, "#crop_resized!" do

  before(:each) do
    @uploaded_file = class << self; self end
    @uploaded_file.extend( UploadColumn::Manipulators::RMagick )
    @uploaded_file.load_manipulator_dependencies
    @uploaded_file.stub!(:path).and_return('/some_path.png')
  end

  it "should use rmagick to resize and crop the image to the appropriate size" do
    
    img = mock('an image frame')
    @uploaded_file.should_receive(:manipulate!).and_yield(img)
    
    img.should_receive(:crop_resized).with(200, 200)
    
    @uploaded_file.crop_resized!("200x200")
  end

end

describe UploadColumn::Manipulators::RMagick, "#convert!" do

  before(:each) do
    @uploaded_file = class << self; self end
    @uploaded_file.extend( UploadColumn::Manipulators::RMagick )
    @uploaded_file.load_manipulator_dependencies
    @uploaded_file.stub!(:path).and_return('/some_path.png')
  end

  it "should use rmagick to change the image format" do
    
    img = mock('an image frame')
    @uploaded_file.should_receive(:manipulate!).and_yield(img)
    
    img.should_receive(:format=).with("PNG")
    
    @uploaded_file.convert!(:png)
  end

end

describe UploadColumn::Manipulators::RMagick, "#process!" do

  before(:each) do
    @uploaded_file = class << self; self end
    @uploaded_file.extend( UploadColumn::Manipulators::RMagick )
    @uploaded_file.load_manipulator_dependencies
    @uploaded_file.stub!(:path).and_return('/some_path.png')
  end

  it "should resize the image if a string like '333x444' is passed" do
    @uploaded_file.should_receive(:resize!).with('333x444')
    @uploaded_file.process!('333x444')
  end
  
  it "should crop and resize the image if a string like 'c333x444' is passed" do
    @uploaded_file.should_receive(:crop_resized!).with('333x444')
    @uploaded_file.process!('c333x444')
  end
  
  it "should pass on a proc to manipulate!" do
    img_frame = mock('an image frame')
    proc = proc { |img| img.solarize }
    img_frame.should_receive(:solarize)
    
    @uploaded_file.should_receive(:manipulate!).and_yield(img_frame)
    
    @uploaded_file.process!(proc)
  end
  
  it "should yield to manipulate! if a block is given" do
    img_frame = mock('an image frame')
    img_frame.should_receive(:solarize)
    
    @uploaded_file.should_receive(:manipulate!).and_yield(img_frame)
    
    @uploaded_file.process! do |img|
      img.solarize
    end
  end
  
  it "should resize first and then yield to manipulate! if both a block and a size string are given" do
    img_frame = mock('an image frame')
    img_frame.should_receive(:solarize)
    
    @uploaded_file.should_receive(:resize!).with('200x200').ordered
    @uploaded_file.should_receive(:manipulate!).ordered.and_yield(img_frame)
    
    @uploaded_file.process!('200x200') do |img|
      img.solarize
    end
  end
  
  it "should do nothing if :none is passed" do
    @uploaded_file.should_not_receive(:manipulate!)
    @uploaded_file.process!(:none)
  end

end



require File.join(File.dirname(__FILE__), 'spec_helper')
require File.join(File.dirname(__FILE__), '../lib/upload_column/manipulators/image_science')

describe UploadColumn::Manipulators::ImageScience, "#resize!" do
  
  before(:each) do
    @uploaded_file = class << self; self end # this is a singleton object
    @uploaded_file.extend( UploadColumn::Manipulators::ImageScience )
    @uploaded_file.load_manipulator_dependencies
    @uploaded_file.stub!(:path).and_return('/some_path.png')
  end
  
  it "should preserve the aspect ratio if the image is too wide" do
    
    image = mock('an image_science object')
    
    ::ImageScience.should_receive(:with_image).with('/some_path.png').and_yield(image)
    
    image.should_receive(:width).and_return(640)
    image.should_receive(:height).and_return(480)
    
    i2 = mock('another stupid mock')
    i2.should_receive(:save).with('/some_path.png')
    
    image.should_receive(:resize).with(160, 120).and_yield(i2)
    
    @uploaded_file.resize!('400x120')  
  end
  
  it "should preserve the aspect ratio if the image is too narrow" do
    
    image = mock('an image_science object')
    
    ::ImageScience.should_receive(:with_image).with('/some_path.png').and_yield(image)
    
    image.should_receive(:width).and_return(640)
    image.should_receive(:height).and_return(480)
    
    i2 = mock('another stupid mock')
    i2.should_receive(:save).with('/some_path.png')
    
    image.should_receive(:resize).with(200, 150).and_yield(i2)
    
    @uploaded_file.resize!('200x400')  
  end
  
  it "should rescale to the exact size if the aspect ratio is the same" do
    
    image = mock('an image_science object')
    
    ::ImageScience.should_receive(:with_image).with('/some_path.png').and_yield(image)
    
    image.should_receive(:width).and_return(640)
    image.should_receive(:height).and_return(480)
    
    i2 = mock('another stupid mock')
    i2.should_receive(:save).with('/some_path.png')
    
    image.should_receive(:resize).with(320, 240).and_yield(i2)
    
    @uploaded_file.resize!('320x240')  
  end
  
  it "should not exceed the dimensions if the image is a rather weird size" do
    
    image = mock('an image_science object')
    
    ::ImageScience.should_receive(:with_image).with('/some_path.png').and_yield(image)
    
    image.should_receive(:width).and_return(737)
    image.should_receive(:height).and_return(237)
    
    i2 = mock('another stupid mock')
    i2.should_receive(:save).with('/some_path.png')
    
    image.should_receive(:resize).with(137, 44).and_yield(i2)
    
    @uploaded_file.resize!('137x137')
  end
  
end


describe UploadColumn::Manipulators::ImageScience, "#crop_resized!" do
  
  before(:each) do
    @uploaded_file = class << self; self end # this is a singleton object
    @uploaded_file.extend( UploadColumn::Manipulators::ImageScience )
    @uploaded_file.load_manipulator_dependencies
    @uploaded_file.stub!(:path).and_return('/some_path.png')
  end
  
  it "should crop and resize an image that is too tall" do
    image = mock('an image_science object')
    
    ::ImageScience.should_receive(:with_image).with('/some_path.png').and_yield(image)
    
    image.should_receive(:width).and_return(640)
    image.should_receive(:height).and_return(480)
    
    i2 = mock('another stupid mock')
    image.should_receive(:resize).with(400, 300).and_yield(i2)
    
    i3 = mock('image science is stupid')
    i2.should_receive(:with_crop).with(0, 90, 400, 210).and_yield(i3)
    
    i3.should_receive(:save).with('/some_path.png')
    
    @uploaded_file.crop_resized!('400x120')
  end
  
  it "should crop and resize an image that is too tall" do
    image = mock('an image_science object')
    
    ::ImageScience.should_receive(:with_image).with('/some_path.png').and_yield(image)
    
    image.should_receive(:width).and_return(640)
    image.should_receive(:height).and_return(480)
    
    i2 = mock('another stupid mock')
    image.should_receive(:resize).with(560, 420).and_yield(i2)
    
    i3 = mock('image science is stupid')
    i2.should_receive(:with_crop).with(180, 0, 380, 420).and_yield(i3)
    
    i3.should_receive(:save).with('/some_path.png')
    
    @uploaded_file.crop_resized!('200x420')
  end
  
  it "should crop and resize an image with the correct aspect ratio" do
    image = mock('an image_science object')
    
    ::ImageScience.should_receive(:with_image).with('/some_path.png').and_yield(image)
    
    image.should_receive(:width).and_return(640)
    image.should_receive(:height).and_return(480)
    
    i2 = mock('another stupid mock')
    image.should_receive(:resize).with(320, 240).and_yield(i2)
    
    i3 = mock('image science is stupid')
    i2.should_receive(:with_crop).with(0, 0, 320, 240).and_yield(i3)
    
    i3.should_receive(:save).with('/some_path.png')
    
    @uploaded_file.crop_resized!('320x240')
  end
  
  it "should crop and resize an image with weird dimensions" do
    image = mock('an image_science object')
    
    ::ImageScience.should_receive(:with_image).with('/some_path.png').and_yield(image)
    
    image.should_receive(:width).and_return(737)
    image.should_receive(:height).and_return(967)
    
    i2 = mock('another stupid mock')
    image.should_receive(:resize).with(333, 437).and_yield(i2)
    
    i3 = mock('image science is stupid')
    i2.should_receive(:with_crop).with(0, 150, 333, 287).and_yield(i3)
    
    i3.should_receive(:save).with('/some_path.png')
    
    @uploaded_file.crop_resized!('333x137')
  end
end

describe UploadColumn::Manipulators::ImageScience, "#process!" do

  before(:each) do
    @uploaded_file = class << self; self end
    @uploaded_file.extend( UploadColumn::Manipulators::ImageScience )
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
  
  it "should do nothing if :none is passed" do
    @uploaded_file.should_not_receive(:manipulate!)
    @uploaded_file.process!(:none)
  end

end


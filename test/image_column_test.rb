require File.join(File.dirname(__FILE__), 'abstract_unit')

#:nodoc:

Image1 = "kerb.jpg"
Image2 = "skanthak.png"
Mime1 = "image/jpeg"
Mime2 = "image/png"
ImageInvalid = "invalid-image.jpg"
MimeInvalid = "image/jpeg"

class Entry < ActiveRecord::Base
end

class UploadColumnProcessTest < Test::Unit::TestCase
  def setup
    TestMigration.up
    Entry.upload_column :image
  end
  
  def teardown
    TestMigration.down
    FileUtils.rm_rf File.dirname(__FILE__)+"/public/images"
  end
  
  def test_process_before_save
    e = Entry.new
    e.image = uploaded_file(Image2, Mime2)
    img = e.image.process do |img|
      img.crop_resized(50, 50)
    end
    assert_image_size(img, 50, 50)
    img = nil
    GC.start
  end
  
  def test_process_after_save
    e = Entry.new
    e.image = uploaded_file(Image2, Mime2)
    assert e.save
    img = e.image.process do |img|
      img.crop_resized(50, 50)
    end
    assert_image_size(img, 50, 50)
    img = nil
    GC.start
  end
  
  def test_process_exclamation_before_save
    e = Entry.new
    e.image = uploaded_file(Image2, Mime2)
    e.image.process! do |img|
      img.crop_resized(50, 50)
    end
    img = read_image(e.image.path)
    assert_image_size(img, 50, 50)
    img = nil
    GC.start
  end
  
  def test_process_exclamation_after_save
    e = Entry.new
    e.image = uploaded_file(Image2, Mime2)
    assert e.save
    e.image.process! do |img|
      img.crop_resized(50, 50)
    end
    img = read_image(e.image.path)
    assert_image_size(img, 50, 50)
    img = nil
    GC.start
  end
end

class ImageColumnSimpleTest < Test::Unit::TestCase
  def setup
    TestMigration.up
    Entry.image_column :image, :versions => { :thumb => "100x100", :flat => "200x100" }
  end
  
  def teardown
    TestMigration.down
    FileUtils.rm_rf File.dirname(__FILE__)+"/public/entry/"
  end
  
  def test_assign
    e = Entry.new
    e.image = uploaded_file(Image1, Mime1)
    assert_not_nil e.image
    assert_not_nil e.image.thumb
    assert_not_nil e.image.flat
    do_test_assign e.image
    do_test_assign e.image.thumb
    do_test_assign e.image.flat
    assert_identical e.image.path, file_path(Image1)
    assert_not_identical e.image.thumb.path, file_path(Image1)
    assert_not_identical e.image.flat.path, file_path(Image1)
  end
  
  def do_test_assign( file )
    assert file.is_a?(UploadColumn::UploadedFile), "#{file.inspect} is not an UploadedFile"
    assert file.respond_to?(:path), "{file.inspect} did not respond to 'path'"
    assert File.exists?(file.path)
  end

  def test_resize_without_save
    e = Entry.new
    e.image = uploaded_file(Image1, Mime1)
    assert_not_nil e.image.thumb
    assert_not_nil e.image.flat
    thumb = read_image(e.image.thumb.path)
    flat = read_image(e.image.flat.path)
    assert_max_image_size thumb, 100, 100
    assert_max_image_size flat, 200, 100
    flat = nil
    thumb = nil
    GC.start
  end

  def test_simple_resize_with_save
    e = Entry.new
    e.image = uploaded_file(Image1, Mime1)
    e.save
    assert_not_nil e.image.thumb
    assert_not_nil e.image.flat
    thumb = read_image(e.image.thumb.path)
    flat = read_image(e.image.flat.path)
    assert_max_image_size thumb, 100, 100
    assert_max_image_size flat, 200, 100
    flat = nil
    thumb = nil
    GC.start
  end

  def test_resize_on_saved_image
    e = Entry.new
    e.image = uploaded_file(Image2, Mime1)
    assert e.save
    e.reload
    old_path = e.image.path
    
    e.image = uploaded_file(Image1, Mime1)
    assert e.save
    assert_not_equal e.image.path, old_path
    assert Image1, e.image.filename
    assert_not_nil e.image.thumb
    assert_not_nil e.image.flat
    thumb = read_image(e.image.thumb.path)
    flat = read_image(e.image.flat.path)
    assert_max_image_size thumb, 100, 100
    assert_max_image_size flat, 200, 100
    flat = nil
    thumb = nil
    GC.start
  end

  def test_manipulate_with_proc
    Entry.image_column :image, :versions => { :thumb => "100x100", :solarized => proc{|img| img.solarize} }
    e = Entry.new
    e.image = uploaded_file(Image2, Mime2)
    
    thumb = read_image(e.image.thumb.path)
    assert_max_image_size thumb, 100, 100
    
    assert_not_identical e.image.solarized.path, e.image.path
    
    thumb = nil
    GC.start
  end

  def test_invalid_image
    e = Entry.new
    assert_nothing_raised do
      e.image = uploaded_file(ImageInvalid, MimeInvalid)
    end
    assert_nil e.image
    assert e.valid?
  end
  
  def test_force_format
    Entry.image_column :image, :force_format => :png, :versions => { :thumb => "100x100", :flat => "200x100" }
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    assert_equal('png', e.image.filename_extension)
    assert_equal("kerb.png", e.image.filename)
    assert_equal("image/png", e.image.mime_type)
    assert e.save
    assert_equal('png', e.image.filename_extension)
    assert_equal("kerb.png", e.image.filename)
    assert_not_identical( file_path("kerb.jpg"), e.image.path ) 
    assert_equal("image/png", e.image.mime_type)
  end
end

class ImageColumnCropTest < Test::Unit::TestCase
  
  def setup
    TestMigration.up
    Entry.image_column :image, :crop => true, :versions => { :thumb => "100x100", :flat => "200x100" }
  end
  
  def teardown
    TestMigration.down
    FileUtils.rm_rf File.dirname(__FILE__)+"/public/entry/"
  end

  def test_assign
    e = Entry.new
    e.image = uploaded_file(Image1, Mime1)
    assert_not_nil e.image
    assert_not_nil e.image.thumb
    assert_not_nil e.image.flat
    do_test_assign e.image
    do_test_assign e.image.thumb
    do_test_assign e.image.flat
    assert_identical e.image.path, file_path(Image1)
    assert_not_identical e.image.thumb.path, file_path(Image1)
    assert_not_identical e.image.flat.path, file_path(Image1)
  end
  
  def do_test_assign( file )
    assert file.is_a?(UploadColumn::UploadedFile), "#{file.inspect} is not an UploadedFile"
    assert file.respond_to?(:path), "{file.inspect} did not respond to 'path'"
    assert File.exists?(file.path)
  end

  def test_resize_without_save
    e = Entry.new
    e.image = uploaded_file(Image1, Mime1)
    assert_not_nil e.image.thumb
    assert_not_nil e.image.flat
    thumb = read_image(e.image.thumb.path)
    flat = read_image(e.image.flat.path)
    assert_image_size thumb, 100, 100
    assert_image_size flat, 200, 100
    flat = nil
    thumb = nil
    GC.start
  end

  def test_simple_resize_with_save
    e = Entry.new
    e.image = uploaded_file(Image1, Mime1)
    e.save
    assert_not_nil e.image.thumb
    assert_not_nil e.image.flat
    thumb = read_image(e.image.thumb.path)
    flat = read_image(e.image.flat.path)
    assert_image_size thumb, 100, 100
    assert_image_size flat, 200, 100
    flat = nil
    thumb = nil
    GC.start
  end

  def test_resize_on_saved_image
    e = Entry.new
    e.image = uploaded_file(Image2, Mime2)
    assert e.save
    e.reload
    old_path = e.image
    
    e.image = uploaded_file(Image1, Mime1)
    assert e.save
    assert Image1, e.image.filename
    assert_not_nil e.image.thumb
    assert_not_nil e.image.flat
    thumb = read_image(e.image.thumb.path)
    flat = read_image(e.image.flat.path)
    assert_image_size thumb, 100, 100
    assert_image_size flat, 200, 100
    flat = nil
    thumb = nil
    GC.start
  end
  
  def test_crop_selected_images_only
    Entry.image_column :image, :versions => { :thumb => "100x100", :flat => "c200x100" }
    e = Entry.new
    e.image = uploaded_file(Image2, Mime2)
    
    thumb = read_image(e.image.thumb.path)
    flat = read_image(e.image.flat.path)
    assert_max_image_size thumb, 100, 100
    # Thumb is not cropped
    assert_not_equal(100, thumb.columns)
    # Flat IS cropped
    assert_image_size flat, 200, 100
    flat = nil
    thumb = nil
    GC.start
  end
 
   
  def test_do_nothing_with_versions
    Entry.image_column :image, :versions => { :thumb => "100x100", :flat => :none }
    e = Entry.new
 
    assert_nothing_raised(TypeError) { e.image = uploaded_file(Image2, Mime2) }
    
    assert_not_identical( e.image.thumb.path, file_path(Image2) )
    assert_identical( e.image.flat.path, file_path(Image2) )
  end
  
  def test_do_stupid_stuff_with_versions
    Entry.image_column :image, :versions => { :thumb => "100x100", :flat => 654 }
    e = Entry.new
    assert_raise(TypeError) { e.image = uploaded_file(Image2, Mime2) }
  end
  

  def test_invalid_image
    e = Entry.new
    assert_nothing_raised do
      e.image = uploaded_file(ImageInvalid, MimeInvalid)
    end
    assert_nil e.image
    assert e.valid?
  end
end

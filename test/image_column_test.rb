require File.join(File.dirname(__FILE__), 'abstract_unit')

#:nodoc:

I1 = "pict.png"
I2 = "skanthak.png"

class Entry < ActiveRecord::Base
end

class UploadColumnProcessTest < Test::Unit::TestCase
  def setup
    TestMigration.up
    Entry.upload_column :image
  end
  
  def teardown
    TestMigration.down
    FileUtils.rm_rf File.dirname(__FILE__)+"/public/entry/"
  end
  
  def test_process_before_save
    e = Entry.new
    e.image = uploaded_file(I2, "image/png")
    img = e.image.process do |img|
      img.crop_resized(50, 50)
    end
    assert_image_size(img, 50, 50)
    img = nil
    GC.start
  end
  
  def test_process_after_save
    e = Entry.new
    e.image = uploaded_file(I2, "image/png")
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
    e.image = uploaded_file(I2, "image/png")
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
    e.image = uploaded_file(I2, "image/png")
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
    e.image = uploaded_file(I1, "image/png")
    assert_not_nil e.image
    assert_not_nil e.image.thumb
    assert_not_nil e.image.flat
    do_test_assign e.image
    do_test_assign e.image.thumb
    do_test_assign e.image.flat
    assert_identical e.image.path, file_path("pict.png")
    assert_not_identical e.image.thumb.path, file_path("pict.png")
    assert_not_identical e.image.flat.path, file_path("pict.png")
  end
  
  def do_test_assign( file )
    assert file.is_a?(UploadColumn::UploadedFile), "#{file.inspect} is not an UploadedFile"
    assert file.respond_to?(:path), "{file.inspect} did not respond to 'path'"
    assert File.exists?(file.path)
    assert_match %r{^([^/]+/(\d+\.)+\d+)/([^/].+)$}, file.relative_path
  end

  def test_resize_without_save
    e = Entry.new
    e.image = uploaded_file(I1, "image/png")
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
    e.image = uploaded_file(I1, "image/png")
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
    e.image = uploaded_file(I2, "image/png")
    assert e.save
    e.reload
    old_path = e.image.path
    
    e.image = uploaded_file(I1, "image/png")
    assert e.save
    assert_not_equal e.image.path, old_path
    assert I1, e.image.filename
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

  def test_invalid_image
    e = Entry.new
    assert_nothing_raised do
      e.image = uploaded_file("invalid-image.jpg", "image/jpeg")
    end
    assert_nil e.image
    assert e.valid?
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
    e.image = uploaded_file(I1, "image/png")
    assert_not_nil e.image
    assert_not_nil e.image.thumb
    assert_not_nil e.image.flat
    do_test_assign e.image
    do_test_assign e.image.thumb
    do_test_assign e.image.flat
    assert_identical e.image.path, file_path("pict.png")
    assert_not_identical e.image.thumb.path, file_path("pict.png")
    assert_not_identical e.image.flat.path, file_path("pict.png")
  end
  
  def do_test_assign( file )
    assert file.is_a?(UploadColumn::UploadedFile), "#{file.inspect} is not an UploadedFile"
    assert file.respond_to?(:path), "{file.inspect} did not respond to 'path'"
    assert File.exists?(file.path)
    assert_match %r{^([^/]+/(\d+\.)+\d+)/([^/].+)$}, file.relative_path
  end

  def test_resize_without_save
    e = Entry.new
    e.image = uploaded_file(I1, "image/jpeg")
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
    e.image = uploaded_file(I1, "image/jpeg")
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
    e.image = uploaded_file(I2, "image/png")
    assert e.save
    e.reload
    old_path = e.image
    
    e.image = uploaded_file(I1, "image/jpeg")
    assert e.save
    assert I1, e.image.filename
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

  def test_invalid_image
    e = Entry.new
    assert_nothing_raised do
      e.image = uploaded_file("invalid-image.jpg", "image/jpeg")
    end
    assert_nil e.image
    assert e.valid?
  end
end

require File.join(File.dirname(__FILE__), 'abstract_unit')

#:nodoc:

class Entry < ActiveRecord::Base
    attr_accessor :validation_should_fail, :iaac
    
    def validate
        errors.add("image","some stupid error") if @validation_should_fail
    end
end

class Movie < ActiveRecord::Base
end


class UploadColumnTest < Test::Unit::TestCase
  
  def setup
    TestMigration.up
    # we define the upload_columns here so that we can change
    # settings easily in a single tes
    Entry.upload_column :image
    Entry.upload_column :file
    Movie.upload_column :movie
  end
  
  def teardown
    TestMigration.down
    FileUtils.rm_rf( File.dirname(__FILE__)+"/public/entry/" )
    FileUtils.rm_rf( File.dirname(__FILE__)+"/public/donkey/" )
    FileUtils.rm_rf( File.dirname(__FILE__)+"/public/movie/" )
  end

  # A convenience helper, since we'll be doing this a lot
  def upload_entry
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    return e
  end

  def test_column_write_method
    assert Entry.new.respond_to?("image=")
  end
  
  def test_column_read_method
    assert Entry.new.respond_to?("image")
  end
  
  def test_sanitize_filename
    e = upload_entry
    e.image.filename = ("test.jpg")
    assert_equal "test.jpg", e.image.filename

    e.image.filename = ("test-s,%&m#st?.jpg")
    assert_equal "test-s___m_st_.jpg", e.image.filename, "weird signs not escaped"

    e.image.filename = ("../../very_tricky/foo.bar")
    assert e.image.filename !~ /[\\\/]/, "slashes not removed"

    e.image.filename = ('`*foo')
    assert_equal "__foo", e.image.filename

    e.image.filename = ('c:\temp\foo.txt')
    assert_equal "foo.txt", e.image.filename

    e.image.filename = (".")
    assert_equal "_.", e.image.filename
  end
  
  def test_default_options
    e = upload_entry
    assert_equal File.join(RAILS_ROOT, "public"), e.image.options[:root_path]
    assert_equal "", e.image.options[:web_root]
    assert_equal UploadColumn::MIME_EXTENSIONS, e.image.options[:mime_extensions]
    assert_equal UploadColumn::EXTENSIONS, e.image.options[:extensions]
    assert_equal true, e.image.options[:fix_file_extensions]
    assert_equal nil, e.image.options[:store_dir]
    assert_equal true, e.image.options[:store_dir_append_id]
    assert_equal true, e.image.options[:replace_old_files]
    assert_equal "tmp", e.image.options[:tmp_dir]
  end
  
  def test_assign_without_save_with_tempfile
    e = upload_entry
    do_test_assign(e)
  end
  
  def test_assign_without_save_with_stringio
    e = Entry.new
    e.image = uploaded_stringio("skanthak.png", "image/png")
    do_test_assign(e)
  end
  
  def do_test_assign(e)
    assert e.image.is_a?(UploadColumn::UploadedFile), "#{e.image.inspect} is not an UploadedFile"
    assert e.image.respond_to?(:path), "{e.image.inspect} did not respond to 'path'"
    assert File.exists?(e.image.path)
    assert_identical e.image.path, file_path("skanthak.png")
    assert_match %r{^([^/]+/(\d+\.)+\d+)/([^/].+)$}, e.image.relative_path
  end
  
  def test_filename_preserved
    e = upload_entry
    assert_equal "skanthak.png", e.image.to_s
    assert_equal "skanthak.png", e.image.filename
    assert_equal "skanthak", e.image.filename_base
    assert_equal "png", e.image.filename_extension
  end
  
  def test_filename_stored_in_attribute
    e = Entry.new("image" => uploaded_file("kerb.jpg", "image/jpeg"))
    assert e.image.is_a?(UploadColumn::UploadedFile), "#{e.image.inspect} is not an UploadedFile"
    assert e.image.respond_to?(:path), "{e.image.inspect} did not respond to 'path'"
    assert File.exists?(e.image.path)
    assert_identical e.image.path, file_path("kerb.jpg")
  end
  
  def test_extension_added
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg", "kerb")
    assert_equal "kerb.jpg", e.image.filename
    assert_equal "kerb.jpg", e["image"]
  end
  
  def test_extension_unknown_type
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "not/known", "kerb")
    assert_equal "kerb", e.image.filename
    assert_equal "kerb", e["image"]
  end

  def test_extension_unknown_type_with_extension
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "not/known", "kerb.abc")
    assert_equal "kerb.abc", e.image.filename
    assert_equal "kerb.abc", e["image"]
  end

  def test_extension_corrected
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg", "kerb.jpeg")
    assert_equal "kerb.jpg", e.image.filename
    assert_equal "kerb.jpg", e["image"]
  end

  def test_double_extension
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "application/x-tgz", "kerb.tar.gz")
    assert_equal "kerb.tar.gz", e.image.filename
    assert_equal "kerb.tar.gz", e["image"]
  end

  def test_get_content_type_with_file

    # run this test only if the machine we are running on
    # has the file utility installed
    if File.executable?("file")
      e = Entry.new
      e.image = uploaded_file("kerb") # no content type passed
      assert_equal "kerb.jpg", e.image.filename
      assert_equal "kerb.jpg", e["image"]
    else
      puts "Warning: Skipping test_get_content_type_with_file test as 'file' does not exist"
    end
  end

  def test_do_not_fix_file_extensions
    Entry.upload_column :image, :fix_file_extensions => false
    e = Entry.new
    e.image = uploaded_file("kerb.jpeg") # no content type passed
    assert_equal "kerb.jpeg", e.image.filename
    assert_equal "kerb.jpeg", e["image"]
    e.image = uploaded_file("kerb") # no content type passed
    assert_equal "kerb", e.image.filename
    assert_equal "kerb", e["image"]
  end

  def test_assign_with_save
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    tmp_file_path = e.image.path
    assert e.save
    assert File.exists?(e.image.path)
    assert FileUtils.identical?(e.image.path, file_path("kerb.jpg"))
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'entry', 'image', e.id.to_s, "kerb.jpg")), e.image.path
    assert_equal "#{e.id}/kerb.jpg", e.image.relative_path
    assert !File.exists?(tmp_file_path), "temporary file '#{tmp_file_path}' not removed"
    assert !File.exists?(File.dirname(tmp_file_path)), "temporary directory '#{File.dirname(tmp_file_path)}' not removed"
    
    local_path = e.image.path
    e = Entry.find(e.id)
    assert e.image.is_a?(UploadColumn::UploadedFile), "#{e.image.inspect} is not an UploadedFile"
    assert e.image.respond_to?(:path), "{e.image.inspect} did not respond to 'path'"
    assert File.exists?(e.image.path)
    assert_equal local_path, e.image.path
    assert_identical e.image.path, file_path("kerb.jpg")
  end
  
  def test_dir_methods
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    e.save
    
    assert_equal File.expand_path(File.join(RAILS_ROOT, "public", "entry", "image", e.id.to_s)), e.image.store_dir
    assert_equal File.join("entry", "image", e.id.to_s), e.image.relative_dir
  end
  
  def test_assign_with_save_and_multiple_versions
    Entry.upload_column :image, :versions => [ :thumb, :large ]
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg")

    tmp_file_path = e.image.path

    assert e.save
    assert File.exists?(e.image.path)

    assert e.image.thumb.is_a?(UploadColumn::UploadedFile), "#{e.image.inspect} is not an UploadedFile"
    assert File.exists?(e.image.thumb.path)
    assert_identical e.image.thumb.path, file_path("kerb.jpg")
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'entry', 'image', e.id.to_s, "kerb-thumb.jpg")), e.image.thumb.path
    assert_equal "#{e.id}/kerb-thumb.jpg", e.image.thumb.relative_path

    assert e.image.large.is_a?(UploadColumn::UploadedFile), "#{e.image.inspect} is not an UploadedFile"
    assert File.exists?(e.image.large.path)
    assert_identical e.image.large.path, file_path("kerb.jpg")
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'entry', 'image', e.id.to_s, "kerb-large.jpg")), e.image.large.path
    assert_equal "#{e.id}/kerb-large.jpg", e.image.large.relative_path

    assert !File.exists?(File.dirname(tmp_file_path)), "temporary directory '#{File.dirname(tmp_file_path)}' not removed"
    
    local_path = e.image.thumb.path
    e = Entry.find(e.id)
    assert e.image.thumb.is_a?(UploadColumn::UploadedFile), "#{e.image.inspect} is not an UploadedFile"
    assert File.exists?(e.image.thumb.path)
    assert_equal local_path, e.image.thumb.path
    assert_identical e.image.thumb.path, file_path("kerb.jpg")    
    
  end

  def test_absolute_path_is_simple
    # we make :root_path more complicated to test that it is normalized in absolute paths
    Entry.upload_column :image, {:root_path => File.join(RAILS_ROOT, "public") + "/../public" }
    
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    assert File.exists?(e.image.path)
    assert e.image.path !~ /\.\./, "#{e.image.path} is not a simple path"
  end


  def test_cleanup_after_destroy
    e = Entry.new("image" => uploaded_file("kerb.jpg", "image/jpeg"))
    assert e.save
    local_path = e.image.path
    assert File.exists?(local_path)
    assert e.destroy
    assert !File.exists?(local_path), "'#{local_path}' still exists although entry was destroyed"
    assert !File.exists?(File.dirname(local_path))
  end
  
  def test_assign_tmp_image
    e = Entry.new("image" => uploaded_file("kerb.jpg", "image/jpeg") )
    e.validation_should_fail = true
    assert !e.save, "e should not save due to validation errors"
    
    assert_match %r{^([^/]+/(\d+\.)+\d+)/([^/].+)$}, e.image.relative_path
    assert File.exists?(local_path = e.image.path)
        
    image_temp = e.image_temp

    e = Entry.new("image_temp" => image_temp)
    assert_equal local_path, e.image.path
    assert e.save

    assert e.image.is_a?(UploadColumn::UploadedFile), "#{e.image.inspect} is not an UploadedFile"
    assert File.exists?(e.image.path)
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'entry', 'image', e.id.to_s, "kerb.jpg")), e.image.path
    assert_equal "#{e.id}/kerb.jpg", e.image.relative_path
    assert_identical e.image.path, file_path("kerb.jpg")
  end
  
  def test_assign_tmp_image_with_existing_image
    e = Entry.new("image" => uploaded_file("kerb.jpg", "image/jpeg") )
    assert e.save
    assert File.exists?(local_path = e.image.path)

    e = Entry.find(e.id)
    e.image = uploaded_file("skanthak.png", "image/png")  
    e.validation_should_fail = true
    
    assert !e.save
    temp_path = e.image_temp
    
    e = Entry.find(e.id)
    e.image_temp = temp_path
    assert e.save
    
    assert_equal "skanthak.png", e.image.filename
    assert_identical e.image.path, file_path("skanthak.png")
    #assert !File.exists?(local_path), "old image has not been deleted"
  end
  
  def test_replace_tmp_image_temp_first
    do_test_replace_tmp_image([:image_temp, :image])
  end
  
  def test_replace_tmp_image_temp_last
    do_test_replace_tmp_image([:image, :image_temp])
  end
  
  def do_test_replace_tmp_image(order)
    e = Entry.new("image" => uploaded_file("kerb.jpg", "image/jpeg" ) )
    e.validation_should_fail = true
    assert !e.save
    
    image_temp = e.image_temp
    temp_path = e.image.path
    
    new_img = uploaded_file("skanthak.png", "image/png")
    
    e = Entry.new
    for method in order
      case method
      when :image_temp then e.image_temp = image_temp
      when :image then e.image = new_img
      end
    end
    assert e.save
    assert e.image.filename, "skanthak.png"
    assert_identical e.image.path, file_path("skanthak.png"), "'#{e.image}' is not the expected image 'skanthak.png'"
    assert !File.exists?(temp_path), "temporary file '#{temp_path}' is not cleaned up"
    assert !File.exists?(File.dirname(temp_path)), "temporary directory not cleaned up"
  end
  
  
  def test_replace_file_on_saved_object
    e = Entry.new("image" => uploaded_file("kerb.jpg", "image/jpeg"))
    assert e.save
    old_file = e.image.path
    
    e = Entry.find(e.id)
    
    e.image = uploaded_file("skanthak.png", "image/png")
    
    assert e.save
    assert_identical file_path("skanthak.png"), e.image.path
    assert_equal "skanthak.png", e.image.filename
    assert old_file != e.image.path
    #assert !File.exists?(old_file), "'#{old_file}' has not been cleaned up"
  end
  
  def test_edit_without_touching_file
    e = Movie.new("movie" => uploaded_file("kerb.jpg", "image/jpeg"))
    assert e.save
    e = Movie.find(e.id)
    e.name = "arg"
    assert e.save
    assert_equal "arg", e.name
    assert_equal "kerb.jpg", e.movie.filename
    assert_identical file_path("kerb.jpg"), e.movie.path
  end
  
  def test_save_without_image
    e = Entry.new
    assert e.save
    e.reload
    assert_nil e.image
  end
  
  def test_delete_saved_image
    e = Entry.new("image" => uploaded_file("kerb.jpg", "image/jpeg"))
    assert e.save
    local_path = e.image.path
    e.image = nil
    assert_nil e.image
    assert File.exists?(local_path), "file '#{local_path}' should not be deleted until transaction is saved"
    assert e.save
    assert_nil e.image
    #assert !File.exists?(local_path)
    e.reload
    assert_nil e["image"]
    e = Entry.find(e.id)
    assert_nil e.image
  end
  
  def test_delete_nonexistant_image
    e = Entry.new
    e.image = nil
    assert e.save
    assert_nil e.image
  end
  
  def test_ie_filename
    e = Entry.new("image" => uploaded_file("kerb.jpg", "image/jpeg", 'c:\images\kerb.jpg'))

    assert_equal "kerb.jpg", e.image.filename
    assert e.image.relative_path =~ /^tmp\/[\d\.]+\/kerb\.jpg$/, "relative path '#{e.image.relative_path}' was not as expected"
    assert File.exists?(e.image.path)
  end
  
  
  def test_empty_tmp
    e = Entry.new
    e.image_temp = ""
    assert_nil e.image
    e.image_temp = nil
    assert_nil e.image
  end
  
  def test_empty_tmp_with_image
    e = Entry.new
    e.image_temp = ""
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    local_path = e.image.path
    assert_equal "kerb.jpg", e.image.filename
    assert File.exists?(local_path)
    e.image_temp = ""
    assert_equal local_path, e.image.path
  end
  
  def test_empty_filename
    e = Entry.new
    assert_nil e["file"]
    assert_nil e.file
    assert_nil e["image"]
    assert_nil e.image
  end
  
  def test_with_two_upload_columns
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    e.file = uploaded_file("skanthak.png", "image/png")
    assert e.save
    assert_match %{/entry/image/}, e.image.path
    assert_match %{/entry/file/}, e.file.path
    assert_equal e.image.filename, "kerb.jpg"
    assert_equal e.file.filename, "skanthak.png"
    assert_identical e.image.path, file_path("kerb.jpg")
    assert_identical e.file.path, file_path("skanthak.png")
  end
  
  def test_with_two_models
    e = Entry.new(:image => uploaded_file("kerb.jpg", "image/jpeg"))
    m = Movie.new(:movie => uploaded_file("skanthak.png", "image/png"))
    assert e.save
    assert m.save
    assert_match %{/entry/image/}, e.image.path
    assert_match %{/movie/movie/}, m.movie.path
    assert_equal e.image.filename, "kerb.jpg"
    assert_equal m.movie.filename, "skanthak.png"
    assert_identical e.image.path, file_path("kerb.jpg")
    assert_identical m.movie.path, file_path("skanthak.png")
  end

  def test_no_file_uploaded
    e = Entry.new
    assert_nothing_raised do
      e.image = uploaded_stringio(nil, "application/octet-stream", "test")
    end
    assert_equal nil, e.image
  end

  # when safari submits a form where no file has been
  # selected, it does not transmit a content-type and
  # the result is an empty string ""
  def test_no_file_uploaded_with_safari
    e = Entry.new
    assert_nothing_raised { e.image = "" }
    assert_equal nil, e.image
  end

  def test_detect_wrong_encoding
    e = Entry.new
    assert_raise(TypeError) { e.image = "img42.jpg" }
  end


  def test_serializable_before_save
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert_nothing_raised { 
      flash = Marshal.dump(e) 
      e = Marshal.load(flash)
    }
    assert_equal e.image.filename, "skanthak.png"
    assert File.exists?(e.image.path)
  end
  
  def test_url
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert_equal "/entry/image/#{e.image.dir.gsub('\\', '/')}/skanthak.png", e.image.url
    assert e.save
    assert_equal "/entry/image/#{e.id.to_s}/skanthak.png", e.image.url
  end
  
  def test_store_dir
    Entry.upload_column( :image, :store_dir => "donkey")
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'donkey', e.image.dir.gsub('\\', '/'), "skanthak.png")), e.image.path
    assert e.save
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'donkey', e.id.to_s, "skanthak.png")), e.image.path
  end
  
  def test_store_dir_append_id
    Entry.upload_column( :image, :store_dir_append_id => false )
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'entry', 'image', e.image.dir.gsub('\\', '/'), "skanthak.png")), e.image.path
    assert e.save
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'entry', 'image', "skanthak.png")), e.image.path
  end
  
  def test_root_path
    Entry.upload_column( :image, :root_path => File.join( RAILS_ROOT, "public", "donkey") )
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'donkey', 'entry', 'image', e.image.dir.gsub('\\', '/'), "skanthak.png")), e.image.path
    assert e.save
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'donkey', 'entry', 'image', e.id.to_s, "skanthak.png")), e.image.path
  end
  
  def test_web_root
    Entry.upload_column( :image, :web_root => "donkey/test" )
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert_equal "/donkey/test/entry/image/#{e.image.dir.gsub('\\', '/')}/skanthak.png", e.image.url
    assert e.save
    assert_equal "/donkey/test/entry/image/#{e.id.to_s}/skanthak.png", e.image.url
  end
  
  def test_slashed_web_root
    Entry.upload_column( :image, :web_root => "/donkey/test" )
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert_equal "/donkey/test/entry/image/#{e.image.dir.gsub('\\', '/')}/skanthak.png", e.image.url
  end
  
  def test_replace_old_files
    # TODO: make this work!
  end
  
  def test_tmp_dir
    Entry.upload_column( :image, :tmp_dir => "old/tmp" )
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert_match %r{^old/tmp}, e.image.dir
  end
  
  def test_slashed_tmp_dir
    Entry.upload_column( :image, :tmp_dir => "/old/tmp" )
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert_match %r{^old/tmp}, e.image.dir
  end
  
  def test_size
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert_equal e.image.size, 12629
    assert e.save
    assert_equal e.image.size, 12629
  end
  
  def test_set_path
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    e.image.set_path("tmp/1234.56789.1234/donkey.tiff")
    assert_equal e.image.filename, "donkey.tiff"
    assert_equal e.image.dir, "tmp/1234.56789.1234"
  end
  
  def test_exists
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert e.image.exists?
    assert e.save
    assert e.image.exists?
    e.image.delete
    assert !e.image.exists?
  end
  
  def test_to_s
    e = upload_entry
    assert_equal e.image.filename, e.image.to_s
  end
  
  def test_mime_type
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert e.save
    assert_equal e.image.mime_type, "image/png"
  end
  
  
end

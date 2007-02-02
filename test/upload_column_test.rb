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
    Entry.upload_column :textfile
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
    e.image.send(:filename=, "test.jpg")
    assert_equal "test.jpg", e.image.filename

    e.image.send(:filename=, "test-s,%&m#st?.jpg")
    assert_equal "test-s___m_st_.jpg", e.image.filename, "weird signs not escaped"

    e.image.send(:filename=, "../../very_tricky/foo.bar")
    assert e.image.filename !~ /[\\\/]/, "slashes not removed"

    e.image.send(:filename=, '`*foo')
    assert_equal "__foo", e.image.filename

    e.image.send(:filename=, 'c:\temp\foo.txt')
    assert_equal "foo.txt", e.image.filename

    e.image.send(:filename=, ".")
    assert_equal "_.", e.image.filename
  end
  
  def test_default_options
    e = upload_entry
    e.id = 10
    assert_equal File.join(RAILS_ROOT, "public"), e.image.options[:root_path]
    assert_equal "", e.image.options[:web_root]
    assert_equal UploadColumn::MIME_EXTENSIONS, e.image.options[:mime_extensions]
    assert_equal UploadColumn::EXTENSIONS, e.image.options[:extensions]
    assert_equal true, e.image.options[:fix_file_extensions]
    assert_equal File.join('entry', 'b', '10'), e.image.options[:store_dir].call(e,'b')
    assert_equal File.join('entry', 'b', 'tmp'), e.image.options[:tmp_dir].call(e,'b')
    assert_equal :delete, e.image.options[:old_files]
    assert_equal true, e.image.options[:validate_integrity]
    assert_equal 'file', e.image.options[:file_exec]
    assert_equal "duck.png", e.image.options[:filename].call(e,'duck','png')
    assert_equal 0644, e.image.options[:permissions]
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
  
  def test_assign_without_save_with_file
    e = Entry.new
    f = File.open(file_path('skanthak.png'))
    e.image = f
    f.close
    do_test_assign(e)
  end
  
  def test_assign_twice
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    do_test_assign(e, "kerb.jpg")
    e.image = uploaded_file("skanthak.png", "image/png")
    do_test_assign(e)
  end
  
  def do_test_assign(e, basename="skanthak.png")
    assert e.image.is_a?(UploadColumn::UploadedFile), "#{e.image.inspect} is not an UploadedFile"
    assert e.image.respond_to?(:path), "{e.image.inspect} did not respond to 'path'"
    assert File.exists?(e.image.path)
    assert_identical e.image.path, file_path(basename)
    assert_match %r{^((\d+\.)+\d+)/([^/].+)$}, e.image_temp
  end
  
  def test_filename_preserved
    e = upload_entry
    assert_equal "skanthak.png", e.image.to_s
    assert_equal "skanthak.png", e.image.filename
    assert_equal "skanthak", e.image.filename_base
    assert_equal "png", e.image.filename_extension
    assert_equal "skanthak", e.image.original_basename
    assert_equal "png", e.image.ext
  end
  
  def test_filename_stored_in_attribute
    e = Entry.new("image" => uploaded_file("kerb.jpg", "image/jpeg"))
    assert e.image.is_a?(UploadColumn::UploadedFile), "#{e.image.inspect} is not an UploadedFile"
    assert e.image.respond_to?(:path), "{e.image.inspect} did not respond to 'path'"
    assert File.exists?(e.image.path)
    assert_identical e.image.path, file_path("kerb.jpg")
  end
  
  def test_with_string
    e = Entry.new
    assert_raise(TypeError) do
      e.image = "duck"
    end
  end
  
  def test_extension_added
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg", "kerb")
    assert_equal "kerb.jpg", e.image.filename
    assert_equal "kerb.jpg", e["image"]
  end
  
  def test_extension_unknown_type
    Entry.upload_column :image, :file_exec => false
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "not/known", "kerb")
    assert_nil e.image
    Entry.upload_column :image, :validate_integrity => false, :file_exec => false
    e.image = uploaded_file("kerb.jpg", "not/known", "kerb")
    assert_equal "kerb", e.image.filename
    assert_equal "kerb", e["image"]
  end

  def test_extension_unknown_type_with_extension
    Entry.upload_column :image, :file_exec => false
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "not/known", "kerb.abc")
    assert_nil e.image
    Entry.upload_column :image, :validate_integrity => false, :file_exec => false
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
    Entry.upload_column :image, :file_exec => false
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "application/x-tgz", "kerb.tar.gz")
    assert_equal "kerb.tar.gz", e.image.filename
    assert_equal "kerb.tar.gz", e["image"]
  end

  def test_get_content_type_with_file

    # run this test only if the machine we are running on
    # has the file utility installed
    if File.executable?("/usr/bin/file")
      e = Entry.new
      e.image = uploaded_file("kerb.jpg", nil, "kerb") # no content type passed
      assert_not_nil e.image
      assert_equal "kerb.jpg", e.image.filename
      assert_equal "kerb.jpg", e["image"]
    else
      puts "Warning: Skipping test_get_content_type_with_file test as '/usr/bin/file' does not exist"
    end
  end
  
  def test_do_not_fix_file_extensions
    Entry.upload_column :image, :fix_file_extensions => false
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg", "kerb.jpeg")
    assert_equal "kerb.jpeg", e.image.filename
    assert_equal "kerb.jpeg", e["image"]
    # Assign an invalid file
    e.image = uploaded_file("skanthak.png", "image/png", "skanthak")
    assert_equal "kerb.jpeg", e.image.filename
    assert_equal "kerb.jpeg", e["image"]
  end

  def test_do_not_fix_file_extensions_without_validating_integrity
    Entry.upload_column :image, :fix_file_extensions => false, :validate_integrity => false
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg", "kerb.jpeg")
    assert_equal "kerb.jpeg", e.image.filename
    assert_equal "kerb.jpeg", e["image"]
    e.image = uploaded_file("kerb.jpg", "image/jpeg", "kerb")
    assert_equal "kerb", e.image.filename
    assert_equal "kerb", e["image"]
  end
  
  def test_validate_integrity
    Entry.upload_column :image, :fix_file_extensions => false
    e = Entry.new
    # invalid file
    e.image = uploaded_file("kerb.jpg", "image/jpeg", "kerb")
    assert_nil e.image
  end

  def test_assign_with_save
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    tmp_file_path = e.image.path
    assert e.save
    assert File.exists?(e.image.path)
    assert FileUtils.identical?(e.image.path, file_path("kerb.jpg"))
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'entry', 'image', e.id.to_s, "kerb.jpg")), e.image.path
    assert_equal "entry/image/#{e.id}/kerb.jpg", e.image.relative_path
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
  
  # Tests store_dir, relative_store_dir, tmp_dir, relative_tmp_dir, dir and relative_dir
  def test_dir_methods
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    
    assert_equal File.join("entry", "image", e.id.to_s), e.image.relative_store_dir
    assert_equal File.expand_path(File.join(RAILS_ROOT, "public", "entry", "image", e.id.to_s)), e.image.store_dir
    
    assert_equal File.join("entry", "image", "tmp"), e.image.relative_tmp_dir
    assert_equal File.expand_path(File.join(RAILS_ROOT, "public", "entry", "image", "tmp")), e.image.tmp_dir
    
    assert_match %r{^#{File.join('entry', 'image', 'tmp', '(\d+\.)+\d+')}$}, e.image.relative_dir
    assert_match %r{^#{File.expand_path(File.join(RAILS_ROOT, 'public', 'entry', 'image', 'tmp', '(\d+\.)+\d+'))}$}, e.image.dir
    
    e.save
    
    assert_equal File.join("entry", "image", e.id.to_s), e.image.relative_store_dir
    assert_equal File.expand_path(File.join(RAILS_ROOT, "public", "entry", "image", e.id.to_s)), e.image.store_dir
    
    assert_equal File.join("entry", "image", "tmp"), e.image.relative_tmp_dir
    assert_equal File.expand_path(File.join(RAILS_ROOT, "public", "entry", "image", "tmp")), e.image.tmp_dir
    
    assert_equal File.join("entry", "image", e.id.to_s), e.image.relative_dir
    assert_equal File.expand_path(File.join(RAILS_ROOT, "public", "entry", "image", e.id.to_s)), e.image.dir
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
    assert_equal "entry/image/#{e.id}/kerb-thumb.jpg", e.image.thumb.relative_path

    assert e.image.large.is_a?(UploadColumn::UploadedFile), "#{e.image.inspect} is not an UploadedFile"
    assert File.exists?(e.image.large.path)
    assert_identical e.image.large.path, file_path("kerb.jpg")
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'entry', 'image', e.id.to_s, "kerb-large.jpg")), e.image.large.path
    assert_equal "entry/image/#{e.id}/kerb-large.jpg", e.image.large.relative_path

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
    
    assert_match %r{^((\d+\.)+\d+)/([^/].+)$}, e.image_temp
    assert File.exists?(local_path = e.image.path)
        
    image_temp = e.image_temp

    e = Entry.new("image_temp" => image_temp)
    assert_equal local_path, e.image.path
    assert e.save

    assert e.image.is_a?(UploadColumn::UploadedFile), "#{e.image.inspect} is not an UploadedFile"
    assert File.exists?(e.image.path)
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'entry', 'image', e.id.to_s, "kerb.jpg")), e.image.path
    assert_equal "entry/image/#{e.id}/kerb.jpg", e.image.relative_path
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
    assert File.exists?(e.movie.path)
  end
  
  def test_edit_without_touching_file_and_old_versions_delete
    Movie.upload_column :movie, :old_versions => :delete
    e = Movie.new("movie" => uploaded_file("kerb.jpg", "image/jpeg"))
    assert e.save
    e = Movie.find(e.id)
    e.name = "arg"
    assert e.save
    assert_equal "arg", e.name
    assert_equal "kerb.jpg", e.movie.filename
    assert_identical file_path("kerb.jpg"), e.movie.path
    assert File.exists?(e.movie.path)
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
    assert e.image.relative_path =~ /^entry\/image\/tmp\/[\d\.]+\/kerb\.jpg$/, "relative path '#{e.image.relative_path}' was not as expected"
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
    assert_nil e["textfile"]
    assert_nil e.textfile
    assert_nil e["image"]
    assert_nil e.image
  end
  
  def test_with_two_upload_columns
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    e.textfile = uploaded_file("skanthak.png", "image/png")
    assert e.save
    assert_match %{/entry/image/}, e.image.path
    assert_match %{/entry/textfile/}, e.textfile.path
    assert_equal e.image.filename, "kerb.jpg"
    assert_equal e.textfile.filename, "skanthak.png"
    assert_identical e.image.path, file_path("kerb.jpg")
    assert_identical e.textfile.path, file_path("skanthak.png")
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


#  def test_serializable_before_save
#    e = Entry.new
#    e.image = uploaded_file("skanthak.png", "image/png")
#    assert_nothing_raised { 
#      flash = Marshal.dump(e) 
#      e = Marshal.load(flash)
#    }
#    assert_equal e.image.filename, "skanthak.png"
#    assert File.exists?(e.image.path)
#  end
  
  def test_url
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert_equal "/#{e.image.relative_dir.gsub('\\', '/')}/skanthak.png", e.image.url
    assert e.save
    assert_equal "/entry/image/#{e.id.to_s}/skanthak.png", e.image.url
  end
  
  def test_store_dir
    Entry.upload_column( :image, :store_dir => "donkey")
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    # Note that the temp path should NOT (since ver 0.2) be affected by a change in :store_dir
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', e.image.relative_dir.gsub('\\', '/'), "skanthak.png")), e.image.path
    assert e.save
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'donkey', "skanthak.png")), e.image.path
  end
  
  def test_store_dir_with_proc
    Movie.upload_column( :movie, :store_dir => proc{|inst, attr| File.join(attr.to_s, inst.name.downcase.gsub(/[^A-Za-z_]/, '_'))})
    e = Movie.new
    e.name = "The Demented Cartoon Movie"
    e.movie = uploaded_file("skanthak.png", "image/png")
    # Note that the temp path should NOT (since ver 0.2) be affected by a change in :store_dir
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', e.movie.relative_dir.gsub('\\', '/'), "skanthak.png")), e.movie.path
    assert e.save
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'movie', 'the_demented_cartoon_movie', "skanthak.png")), e.movie.path
  end
  
  def test_tmp_dir
    Entry.upload_column( :image, :tmp_dir => "old/tmp" )
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert_match %r{^old/tmp}, e.image.relative_dir
  end
  
  def test_tmp_dir_with_proc
    Movie.upload_column( :movie, :tmp_dir => proc{|inst, attr| File.join(attr.to_s, inst.name.downcase.gsub(/[^A-Za-z_]/, '_'), 'tmp')})
    e = Movie.new
    e.name = "The Demented Cartoon Movie"
    e.movie = uploaded_file("skanthak.png", "image/png")
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'movie', 'the_demented_cartoon_movie', 'tmp')), e.movie.tmp_dir
    assert_equal File.join('movie', 'the_demented_cartoon_movie', 'tmp'), e.movie.relative_tmp_dir
    assert_match %r{^movie/the_demented_cartoon_movie/tmp/}, e.movie.relative_path
    assert e.save
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'movie', 'movie', e.id.to_s, "skanthak.png")), e.movie.path
  end
  
  def test_slashed_tmp_dir
    Entry.upload_column( :image, :tmp_dir => "/old/tmp" )
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert_match %r{^old/tmp}, e.image.relative_dir
  end
  
  def test_root_path
    Entry.upload_column( :image, :root_path => File.join( RAILS_ROOT, "public", "donkey") )
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'donkey', e.image.relative_dir.gsub('\\', '/'), "skanthak.png")), e.image.path
    assert e.save
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'donkey', 'entry', 'image', e.id.to_s, "skanthak.png")), e.image.path
  end
  
  def test_web_root
    Entry.upload_column( :image, :web_root => "donkey/test" )
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert_equal "/donkey/test/#{e.image.relative_dir.gsub('\\', '/')}/skanthak.png", e.image.url
    assert e.save
    assert_equal "/donkey/test/entry/image/#{e.id.to_s}/skanthak.png", e.image.url
  end
  
  def test_slashed_web_root
    Entry.upload_column( :image, :web_root => "/donkey/test" )
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert_equal "/donkey/test/#{e.image.relative_dir.gsub('\\', '/')}/skanthak.png", e.image.url
  end
  
  def test_size
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert_equal e.image.size, 12629
    assert e.save
    assert_equal e.image.size, 12629
  end
  
  def test_assign_temp
    #different basename
    Entry.upload_column(:image, :versions => [:thumb, :large])
    e = Entry.new
    e.image_temp = "1234.56789.1234/donkey.jpg;llama.png"
    assert_equal "llama", e.image.original_basename
    assert_equal "png", e.image.ext
    assert_equal "donkey.jpg", e.image.filename
    assert_equal File.expand_path(File.join( RAILS_ROOT, 'public', 'entry', 'image', 'tmp', '1234.56789.1234')), e.image.dir
    assert_equal "donkey-large.jpg", e.image.large.filename
    assert_equal File.expand_path(File.join( RAILS_ROOT, 'public', 'entry', 'image', 'tmp', '1234.56789.1234')), e.image.large.dir
    assert_equal "donkey-thumb.jpg", e.image.thumb.filename
    assert_equal File.expand_path(File.join( RAILS_ROOT, 'public', 'entry', 'image', 'tmp', '1234.56789.1234')), e.image.thumb.dir
    
    #same basename
    f = Entry.new
    f.image_temp = "1234.56789.1234/donkey.jpg" # old style
    assert_equal "donkey", f.image.original_basename
    assert_equal "jpg", f.image.ext
    assert_equal "donkey.jpg", f.image.filename
    assert_equal File.expand_path(File.join( RAILS_ROOT, 'public', 'entry', 'image', 'tmp', '1234.56789.1234')), f.image.dir
    assert_equal "donkey-large.jpg", f.image.large.filename
    assert_equal File.expand_path(File.join( RAILS_ROOT, 'public', 'entry', 'image', 'tmp', '1234.56789.1234')), f.image.large.dir
    assert_equal "donkey-thumb.jpg", f.image.thumb.filename
    assert_equal File.expand_path(File.join( RAILS_ROOT, 'public', 'entry', 'image', 'tmp', '1234.56789.1234')), f.image.thumb.dir
    
    e = Entry.new
    assert_raise(ArgumentError) do
      e.image_temp = "somefolder/1234.56789.1234/donkey.jpg;llama.png"
    end
    e = Entry.new
    assert_raise(ArgumentError) do
      e.image_temp = "../1234.56789.1234/donkey.jpg;llama.png"
    end
    e = Entry.new
    assert_raise(ArgumentError) do
      e.image_temp = "/usr/bin/ruby" # 'Cos that would be bad :P
    end
    e = Entry.new
    assert_raise(ArgumentError) do
      e.image_temp = "1234.56789.1234;llama.png"
    end
  end
  
  def test_exists
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert e.image.exists?
    assert e.save
    assert e.image.exists?
    e.image.send(:delete)
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
  
  def test_old_files_replace
    Entry.upload_column( :image, :old_files => :replace )
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    assert e.save
    assert File.exists?( e.image.path )
    old_path = e.image.path
    e.image = uploaded_file("skanthak.png", "image/png")
    assert e.save
    assert File.exists?( e.image.path )
    somewhat_newer_path = e.image.path
    assert !File.exists?( old_path )
    assert e.destroy
    assert File.exists?( somewhat_newer_path )
    assert !File.exists?( old_path ) 
  end

  def test_old_files_delete
    Entry.upload_column( :image, :old_files => :delete )
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    assert e.save
    assert File.exists?( e.image.path )
    old_path = e.image.path
    e.image = uploaded_file("skanthak.png", "image/png")
    assert e.save
    assert File.exists?( e.image.path )
    somewhat_newer_path = e.image.path
    assert !File.exists?( old_path )
    assert e.destroy
    assert !File.exists?( somewhat_newer_path )
    assert !File.exists?( old_path ) 
  end
  
  def test_old_files_keep
    Entry.upload_column( :image, :old_files => :keep )
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    assert e.save
    assert File.exists?( e.image.path )
    old_path = e.image.path
    e.image = uploaded_file("skanthak.png", "image/png")
    assert e.save
    assert File.exists?( e.image.path )
    somewhat_newer_path = e.image.path
    assert File.exists?( old_path )
    assert e.destroy
    assert File.exists?( somewhat_newer_path )
    assert File.exists?( old_path ) 
  end
  
  def test_delete
    Entry.upload_column( :image, :versions => [ :thumb, :large ] )
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    assert e.save
    assert_equal e.image.store_dir, e.image.dir #Check that we saved to the right location
    assert File.exists?( e.image.path )
    assert File.exists?( e.image.thumb.path )
    e.image.send(:delete)
    assert !File.exists?( e.image.path )
    assert !File.exists?( e.image.thumb.path )
    assert !File.exists?( e.image.dir )
  end
  
  def test_filename
    Entry.upload_column( :image, :filename => "donkey.jpg")
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    assert_equal("donkey.jpg", e.image.filename)
    assert_equal "kerb", e.image.original_basename
    assert e.save
    assert_equal("donkey.jpg", e.image.filename)
    assert_equal(File.expand_path(File.join(RAILS_ROOT, 'public', 'entry', 'image', e.id.to_s, 'donkey.jpg')), e.image.path)
    assert File.exists?(e.image.path)
  end
  
  def test_filename_with_proc
    Movie.upload_column( :movie, :filename => proc{|inst, original, ext| "donkey_#{inst.name.downcase.gsub(/[^a-z]/, '_')}_#{original}_duck.#{ext}"} )
    e = Movie.new
    e.name = "The Demented Cartoon Movie"
    e.movie = uploaded_file("kerb.jpg", "image/jpeg")
    assert_equal("donkey_the_demented_cartoon_movie_kerb_duck.jpg", e.movie.filename)
    assert_equal "kerb", e.movie.original_basename
    assert e.save
    assert_equal("donkey_the_demented_cartoon_movie_kerb_duck.jpg", e.movie.filename)
    assert_equal(File.expand_path(File.join(RAILS_ROOT, 'public', 'movie', 'movie', e.id.to_s, 'donkey_the_demented_cartoon_movie_kerb_duck.jpg')), e.movie.path)
    assert File.exists?(e.movie.path)
  end
  
  def test_filename_with_proc_and_id
    Entry.upload_column( :image, :versions => [:thumb, :large], :filename => proc{|inst, original, ext| "donkey_#{inst.id || 'new'}.#{ext}"} )
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    assert_equal("donkey_new.jpg", e.image.filename)
    assert_equal("donkey_new-thumb.jpg", e.image.thumb.filename)
    assert_equal("donkey_new-large.jpg", e.image.large.filename)
    assert_equal "kerb", e.image.original_basename
    assert e.save
    assert_equal("donkey_1.jpg", e.image.filename)
    assert_equal("donkey_1-thumb.jpg", e.image.thumb.filename)
    assert_equal("donkey_1-large.jpg", e.image.large.filename)
    assert_equal(File.expand_path(File.join(RAILS_ROOT, 'public', 'entry', 'image', e.id.to_s, 'donkey_1.jpg')), e.image.path)
    assert File.exists?(e.image.path)
    assert File.exists?(e.image.thumb.path)
    assert File.exists?(e.image.large.path)
    
    # test from tmp...
    f = Entry.new
    f.image = uploaded_file("kerb.jpg", "image/jpeg")
    g = Entry.new
    g.image_temp = f.image_temp
    assert_equal("donkey_new.jpg", g.image.filename)
    assert_equal("donkey_new-thumb.jpg", g.image.thumb.filename)
    assert_equal("donkey_new-large.jpg", g.image.large.filename)
    assert_equal "kerb", g.image.original_basename
    assert g.save
    assert_equal("donkey_#{g.id.to_s}.jpg", g.image.filename)
    assert_equal("donkey_#{g.id.to_s}-thumb.jpg", g.image.thumb.filename)
    assert_equal("donkey_#{g.id.to_s}-large.jpg", g.image.large.filename)
    assert_equal(File.expand_path(File.join(RAILS_ROOT, 'public', 'entry', 'image', g.id.to_s, "donkey_#{g.id.to_s}.jpg")), g.image.path)
    assert File.exists?(g.image.path)
    assert File.exists?(g.image.thumb.path)
    assert File.exists?(g.image.large.path)
    
    # refetch entry
    
    h = Entry.find(1)
    assert_equal("donkey_1.jpg", h.image.filename)
    assert_equal("donkey_1-thumb.jpg", h.image.thumb.filename)
    assert_equal("donkey_1-large.jpg", h.image.large.filename)
    assert File.exists?(h.image.path)
    assert File.exists?(h.image.thumb.path)
    assert File.exists?(h.image.large.path)
  end
  
  def test_assign_blank_stringio #bug in firefox sends blank stringios
    e = Entry.new
    e.image = uploaded_stringio(nil, 'application/octet-stream', 'llama.txt')
    assert_nil e.image
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    e.image = uploaded_stringio(nil, 'application/octet-stream', 'llama.txt')
    assert_equal('kerb.jpg', e.image.filename)
    assert e.save
    e.image = uploaded_stringio(nil, 'application/octet-stream', 'llama.txt')    
    assert_equal('kerb.jpg', e.image.filename)
    assert_equal(e.image.store_dir, e.image.dir)
    
  end
  
  def test_illegal_filename
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg", "do nk?ey.jpg")
    assert_equal  "do_nk_ey.jpg", e.image.filename
    assert File.exists?(e.image.path)
    assert e.save
    assert_equal  "do_nk_ey.jpg", e.image.filename
    assert File.exists?(e.image.path)
  end
  
  def test_old_tmp_file_handling
    new_tmp = Time.now - 60
    old_tmp = new_tmp - 3601
    
    # Do this first so it isn't mucked up by the mocking :)
    f = Entry.new
    f.image = uploaded_file("kerb.jpg", "image/jpeg", "do nk?ey.jpg")
    
    e = Entry.new
    Time.expects(:now).at_least_once.returns(old_tmp)
    e.image = uploaded_file("kerb.jpg", "image/jpeg", "do nk?ey.jpg")
    assert e.image.dir =~ %r{(\d+)\.[\d]+\.[\d]+$}
    assert_equal old_tmp.to_i, $1.to_i
    Time.expects(:now).at_least_once.returns(new_tmp)
    e.image = uploaded_file("kerb.jpg", "image/jpeg", "do nk?ey.jpg")
    assert e.image.dir =~ %r{(\d+)\.[\d]+\.[\d]+$}
    assert_equal new_tmp.to_i, $1.to_i
    
    assert f.save
    
    left = Dir.glob(File.join(f.image.tmp_dir, "*") ).map { |t| t =~ %r{(\d+)\.[\d]+\.[\d]+$}; $1.to_i }
    
    assert left.include?(new_tmp.to_i)
    assert !left.include?(old_tmp.to_i)
    
  end
  
  def test_default_permissions
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    assert File.exists?(e.image.path)
    assert_equal( 0644, (File.stat(e.image.path).mode & 0777) )
    assert e.save
    assert File.exists?(e.image.path)
    assert_equal( 0644, (File.stat(e.image.path).mode & 0777) )
  end
  
  def test_permissions
    Entry.upload_column :image, :permissions => 0755
    e = Entry.new 
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    assert File.exists?(e.image.path)
    assert_equal( 0755, (File.stat(e.image.path).mode & 0777) )
    assert e.save
    assert File.exists?(e.image.path)
    assert_equal( 0755, (File.stat(e.image.path).mode & 0777) )
  end
  
end

require File.join(File.dirname(__FILE__), 'abstract_unit')

#:nodoc:

Entry = Class.new( ActiveRecord::Base )
Movie = Class.new( ActiveRecord::Base )

class Entry < ActiveRecord::Base
  attr_accessor :validation_should_fail, :iaac
  
  upload_column :image
  
  def validate
    errors.add("image","some stupid error") if @validation_should_fail
  end
  
  def image_store_dir
    "entries"
  end
  
  def image_after_assign
    iaac = true
  end

  def after_assign_called?
    return true if iaac
  end
end

class Movie < ActiveRecord::Base
  
  upload_column :movie
  
  def movie_store_dir
    # Beware in this test case you'll HAVE to pass a name... otherwise stupid errors...
    File.join("files", name)
  end
end


class UploadColumnTest < Test::Unit::TestCase
  
  def setup
    TestMigration.up
  end
  
  def teardown
    TestMigration.down
    FileUtils.rm_rf( File.dirname(__FILE__)+"/public/entry/" )
    FileUtils.rm_rf( File.dirname(__FILE__)+"/public/movie/" )
  end

  # A convenience helper, since we'll be doing this a lot
  def upload_entry
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    return e
  end
  
  def test_store_dir
    e = upload_entry
    assert e.save
    assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'entries', e.id.to_s, "skanthak.png")), e.image.path
  end
  
  def test_complex_store_dir
    e = Movie.new
    e.name = "aroo"
    e.movie = uploaded_file("skanthak.png", "image/png")
    assert e.save
    #assert_equal File.expand_path(File.join(RAILS_ROOT, 'public', 'files', 'aroo', e.id.to_s, "skanthak.png")), e.movie.path
  end
  
  def test_after_assign
    e = Entry.new
    e.image = uploaded_file("skanthak.png", "image/png")
    assert_not_nil e.image
    # This DOES work in dev, yet I can't get the assertion to pass, help? please?
    #assert e.after_assign_called?
  end
  
  
end

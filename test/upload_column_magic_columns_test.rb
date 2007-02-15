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

class MimeMigration < ActiveRecord::Migration
  def self.up
    add_column :entries, :image_mime_type, :string
  end
end

class WidthMigration < ActiveRecord::Migration
  def self.up
    add_column :entries, :image_width, :integer
  end
end
  
class HeightMigration < ActiveRecord::Migration
  def self.up
    add_column :entries, :image_height, :integer
  end
end
  
class SizeMigration < ActiveRecord::Migration
  def self.up
    add_column :entries, :image_filesize, :integer
  end
end

class ExifMigration < ActiveRecord::Migration
  def self.up
    add_column :entries, :image_exif_date_time, :datetime
    add_column :entries, :image_exif_model, :string
  end
end

class UploadColumnMagicColumnTest < Test::Unit::TestCase
  
  def setup
    TestMigration.up
    # we define the upload_columns here so that we can change
    # settings easily in a single tes
    Entry.upload_column :image, :file_exec => nil, :validate_integrity => false, :fix_file_extensions => false
  end
  
  def teardown
    TestMigration.down
    Entry.reset_column_information
    Movie.reset_column_information
    FileUtils.rm_rf( File.dirname(__FILE__)+"/public/entry/" )
    FileUtils.rm_rf( File.dirname(__FILE__)+"/public/donkey/" )
    FileUtils.rm_rf( File.dirname(__FILE__)+"/public/movie/" )
  end

  def test_mime_type
    MimeMigration.up
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "text/html", "index.html")
    assert_equal "text/html", e.image.mime_type
    assert_equal "text/html", e.image_mime_type
    assert_equal "text/html", e['image_mime_type']
    assert e.save
    assert_equal "text/html", e.image.mime_type
    assert_equal "text/html", e.image_mime_type
    assert_equal "text/html", e['image_mime_type']
  end
  
  def test_filesize
    SizeMigration.up
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    assert_equal 87582, e.image.size
    assert_equal 87582, e.image_filesize
    assert_equal 87582, e['image_filesize']
    assert e.save
    assert_equal 87582, e.image.size
    assert_equal 87582, e.image_filesize
    assert_equal 87582, e['image_filesize']
  end
  
  def test_magic_columns_from_tmp
    SizeMigration.up
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    f = Entry.new
    f.image_temp = e.image_temp
    assert_equal 87582, f.image.size
    assert_equal 87582, f.image_filesize
    assert_equal 87582, f['image_filesize']
    assert f.save
    assert_equal 87582, f.image.size
    assert_equal 87582, f.image_filesize
    assert_equal 87582, f['image_filesize']
    
  end
  
  def test_width
    WidthMigration.up
    Entry.image_column :image
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/png")
    assert_equal 640, e.image_width
    assert_equal 640, e['image_width']
    assert e.save
    assert_equal 640, e.image_width
    assert_equal 640, e['image_width']
  end
  
  def test_height
    HeightMigration.up
    Entry.image_column :image
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/png")
    assert_equal 480, e.image_height
    assert_equal 480, e['image_height']
    assert e.save
    assert_equal 480, e.image_height
    assert_equal 480, e['image_height']
  end
  
  def test_exif
    ExifMigration.up
    Entry.reset_column_information
    Entry.image_column :image
    e = Entry.new
    e.image = uploaded_file("kerb.jpg", "image/jpeg")
    assert_equal Time.at(1061063810), e.image_exif_date_time
    assert_equal "Canon PowerShot A70", e.image_exif_model
    assert e.save
    assert_equal Time.at(1061063810), e['image_exif_date_time']
    assert_equal "Canon PowerShot A70", e['image_exif_model']
  end
end

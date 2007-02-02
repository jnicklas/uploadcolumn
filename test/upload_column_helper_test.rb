require File.dirname(__FILE__) + '/abstract_unit'
#require 'test_help'

class Entry < ActiveRecord::Base
  upload_column :image
end


class UploadColumnHelperTest < Test::Unit::TestCase
  include UploadColumnHelper
  #include ActionView::Helpers::AssetTagHelper
  #include ActionView::Helpers::TagHelper
  #include ActionView::Helpers::UrlHelper

  attr_accessor :entries

  def setup
    # Can't get fixtures to work, so I'll make them myself :)
    entries = YAML::load(File.open(File.join(RAILS_ROOT, 'fixtures', 'entries.yaml')))
    TestMigration.up
    Entry.upload_column :image
    Entry.upload_column :textfile
    for entry in entries
      e = Entry.new
      e["image"] = entry[1]["image"]
      e["textfile"] = entry[1]["textfile"]
      e.save
    end
  end
  
  def teardown
    TestMigration.down
  end

  def test_fixtures
    e = Entry.find(1)
    assert_nil e.image
    assert_nil e.textfile
    e = Entry.find(2)
    assert e.image.is_a?( UploadColumn::UploadedFile )
    assert e.textfile.is_a?( UploadColumn::UploadedFile )
  end
  
  def test_upload_column_field
    @entry = Entry.new
    assert_not_nil upload_column_field('entry', 'image')
    assert_equal upload_column_field('entry', 'image'), %(<input id="entry_image" name="entry[image]" size="30" type="file" /><input id="entry_image_temp" name="entry[image_temp]" type="hidden" value="" />)
    @entry = Entry.find(1)
    assert_not_nil upload_column_field('entry', 'image')
    assert_equal upload_column_field('entry', 'image'), %(<input id="entry_image" name="entry[image]" size="30" type="file" /><input id="entry_image_temp" name="entry[image_temp]" type="hidden" value="" />)
    @entry = Entry.find(2)
    assert_not_nil upload_column_field('entry', 'image')
    assert_equal upload_column_field('entry', 'image'), %(<input id="entry_image" name="entry[image]" size="30" type="file" /><input id="entry_image_temp" name="entry[image_temp]" type="hidden" value="#{@entry.image_temp}" />)
    @entry = Entry.find(2)
    @entry.image_temp = "1234.56789.1234/kerb.jpg;donkey.png"
    assert_not_nil upload_column_field('entry', 'image')
    assert_equal upload_column_field('entry', 'image'), %(<input id="entry_image" name="entry[image]" size="30" type="file" /><input id="entry_image_temp" name="entry[image_temp]" type="hidden" value="1234.56789.1234/kerb.jpg;donkey.png" />)    
  end
  
end

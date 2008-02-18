module UploadColumn
  
  mattr_accessor :configuration, :image_column_configuration, :extensions, :image_extensions
  
  self.extensions = %w(asf ai avi doc dvi dwg eps gif gz jpg jpeg mov mp3 mpeg odf pac pdf png ppt psd swf swx tar tar.gz torrent txt wmv wav xls zip).freeze
  self.image_extensions = %w(jpg jpeg gif png).freeze
  
  DEFAULT_CONFIGURATION = {
    :tmp_dir => 'tmp',
    :store_dir => proc{ |r, f| f.attribute.to_s },
    :root_dir => File.join(RAILS_ROOT, 'public'),
    :get_content_type_from_file_exec => true,
    :fix_file_extensions => false,
    :process => nil,
    :permissions => 0644,
    :extensions => self.extensions,
    :web_root => '',
    :manipulator => nil,
    :versions => nil,
    :validate_integrity => false
  }
  
  self.configuration = UploadColumn::DEFAULT_CONFIGURATION.clone
  self.image_column_configuration = {
    :manipulator => UploadColumn::Manipulators::RMagick,
    :root_dir => File.join(RAILS_ROOT, 'public', 'images'),
    :web_root => '/images',
    :extensions => self.image_extensions
  }.freeze
  
  def self.configure
    yield ConfigurationProxy.new
  end
  
  def self.reset_configuration
    self.configuration = UploadColumn::DEFAULT_CONFIGURATION.clone
  end
  
  class ConfigurationProxy  
    def method_missing(method, value)
      name = method.to_s.scan(/^(.*?)=$/).first.first.to_sym
      UploadColumn.configuration[name] = value
    end
  end
  
end
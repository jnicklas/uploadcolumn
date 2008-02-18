module UploadColumn
  module MagicColumns
  
    def self.append_features(base)
      super
      base.alias_method_chain :set_upload_column, :magic_columns
      base.alias_method_chain :set_upload_column_temp, :magic_columns
      base.alias_method_chain :save_uploaded_files, :magic_columns
    end
  
    def set_upload_column_with_magic_columns(name, file)
      set_upload_column_without_magic_columns(name, file)
      evaluate_magic_columns_for_upload_column(name)
    end
  
    def set_upload_column_temp_with_magic_columns(name, path)
      set_upload_column_temp_without_magic_columns(name, path)
      evaluate_magic_columns_for_upload_column(name)
    end
    
    def save_uploaded_files_with_magic_columns
      save_uploaded_files_without_magic_columns
      self.class.reflect_on_upload_columns.each do |name, column|
        evaluate_magic_columns_for_upload_column(name)
      end
    end
    
    private
    
    def evaluate_magic_columns_for_upload_column(name)
      self.class.column_names.each do |column_name|
        if predicate = column_name.scan(/^#{name}_([a-z0-9_?!]+)$/).first
          predicate = predicate.first
          self.instance_eval <<-SRC
            self.#{column_name} = self.#{name}.#{predicate} if self.#{name}.respond_to?(:#{predicate})
          SRC
        end
      end
    end
  
  end
end
module ArJdbc
  module SerializedAttributesHelper

    def self.dump_column_value(record, column)
      value = record[ name = column.name.to_s ]
      if record.class.respond_to?(:serialized_attributes)
        if coder = record.class.serialized_attributes[name]
          value = coder.respond_to?(:dump) ? coder.dump(value) : value.to_yaml
        end
      else
        if record.respond_to?(:unserializable_attribute?)
          value = value.to_yaml if record.unserializable_attribute?(name, column)
        else
          value = value.to_yaml if value.is_a?(Hash)
        end
      end
      value
    end
    
  end
end
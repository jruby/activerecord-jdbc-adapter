module ActiveRecord
  module ConnectionAdapters # :nodoc:

    class AbstractAdapter
      protected

      def initialize_type_map(m) # :nodoc:
        register_class_with_limit m, %r(boolean)i,   Type::Boolean
        register_class_with_limit m, %r(char)i,      Type::String
        register_class_with_limit m, %r(binary)i,    Type::Binary
        register_class_with_limit m, %r(text)i,      Type::Text
        register_class_with_limit m, %r(date)i,      Type::Date
        register_class_with_limit m, %r(time)i,      Type::Time
        register_class_with_limit m, %r(datetime)i,  Type::DateTime
        register_class_with_limit m, %r(float)i,     Type::Float
        register_class_with_limit m, %r(int)i,       Type::Integer
        register_class_with_limit m, %r(tinyint)i,   Type::Boolean

        m.alias_type %r(blob)i,      'binary'
        m.alias_type %r(clob)i,      'text'
        m.alias_type %r(timestamp)i, 'datetime'
        m.alias_type %r(numeric)i,   'decimal'
        m.alias_type %r(number)i,    'decimal'
        m.alias_type %r(double)i,    'float'

        m.register_type(%r(decimal)i) do |sql_type|
          scale = extract_scale(sql_type)
          precision = extract_precision(sql_type)

          if scale == 0
            # FIXME: Remove this class as well
            Type::DecimalWithoutScale.new(precision: precision)
          else
            Type::Decimal.new(precision: precision, scale: scale)
          end
        end
      end

    end
  end
end

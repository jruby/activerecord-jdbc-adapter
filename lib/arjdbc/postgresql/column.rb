module ArJdbc
  module PostgreSQL

    # @see ActiveRecord::ConnectionAdapters::JdbcColumn#column_types
    def self.column_selector
      [ /postgre/i, lambda { |cfg, column| column.extend(Column) } ]
    end

    # @private these are defined on the Adapter class since 4.2
    module ColumnHelpers

      def extract_limit(sql_type) # :nodoc:
        case sql_type
        when /^bigint/i, /^int8/i then 8
        when /^smallint/i then 2
        when /^timestamp/i then nil
        else
          super
        end
      end

      # Extracts the value from a PostgreSQL column default definition.
      def extract_value_from_default(oid, default) # :nodoc:
        case default
          # Quoted types
          when /\A[\(B]?'(.*)'::/m
            $1.gsub(/''/, "'")
          # Boolean types
          when 'true', 'false'
            default
          # Numeric types
          when /\A\(?(-?\d+(\.\d*)?)\)?(::bigint)?\z/
            $1
          # Object identifier types
          when /\A-?\d+\z/
            $1
          else
            # Anything else is blank, some user type, or some function
            # and we can't know the value of that, so return nil.
            nil
        end
      end

      def extract_default_function(default_value, default) # :nodoc:
        default if ! default_value && ( %r{\w+\(.*\)} === default )
      end

    end

  end
end

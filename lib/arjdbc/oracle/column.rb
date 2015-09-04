module ArJdbc
  module Oracle

    # @see ActiveRecord::ConnectionAdapters::JdbcColumn#column_types
    def self.column_selector
      [ /oracle/i, lambda { |config, column| column.extend(Column) } ]
    end

    # @see ActiveRecord::ConnectionAdapters::JdbcColumn
    module Column

      def self.included(base)
        # NOTE: assumes a standalone OracleColumn class
        class << base; include Cast; end # unless AR42
      end

      def primary=(value)
        super
        @type = :integer if value && @sql_type =~ /^NUMBER$/i
      end unless AR42

      def type_cast(value)
        return nil if value.nil?
        case type
        when :datetime  then self.class.string_to_time(value)
        when :timestamp then self.class.string_to_time(value)
        when :boolean   then self.class.value_to_boolean(value)
        else
          super
        end
      end

      def type_cast_code(var_name)
        case type
        when :datetime  then "#{self.class.name}.string_to_time(#{var_name})"
        when :timestamp then "#{self.class.name}.string_to_time(#{var_name})"
        when :boolean   then "#{self.class.name}.value_to_boolean(#{var_name})"
        else
          super
        end
      end

      def sql_type
        (@sql_type || '').start_with?('XMLTYPE') ? 'XMLTYPE' : @sql_type
      end

      private

      def extract_limit(sql_type)
        case sql_type
        when /^(clob|date)/i then nil
        when /^xml/i then nil
        else super
        end
      end unless AR42

      def simplified_type(field_type)
        case field_type
        when /char/i            then :string
        when /float|double/i    then :float
        when /int/i             then :integer
        when /^number\(1\)$/i   then Oracle.emulate_booleans? ? :boolean : :integer
        when /^num|dec|real/i   then extract_scale(field_type) == 0 ? :integer : :decimal
        # Oracle TIMESTAMP stores the date and time to up to 9 digits of sub-second precision
        when /TIMESTAMP/i       then :timestamp
        # Oracle DATE stores the date and time to the second
        when /DATE|TIME/i       then :datetime
        when /CLOB/i            then :text
        when /BLOB/i            then :binary
        when /XML/i             then :xml
        else
          super
        end
      end unless AR42

      # Post process default value from JDBC into a Rails-friendly format (columns{-internal})
      def default_value(value)
        return nil unless value
        value = value.strip # Not sure why we need this for Oracle?
        upcase = value.upcase

        return nil if upcase == "NULL"
        # SYSDATE default should be treated like a NULL value
        return nil if upcase == "SYSDATE"
        # jdbc returns column default strings with actual single quotes around the value.
        return $1 if value =~ /^'(.*)'$/

        value
      end

      module Cast

        # Convert a value to a boolean.
        def value_to_boolean(value)
          # NOTE: Oracle JDBC meta-data gets us DECIMAL for NUMBER(1) values
          # thus we're likely to get a column back as BigDecimal (e.g. 1.0)
          if value.is_a?(String)
            value.blank? ? nil : value == '1'
          elsif value.is_a?(Numeric)
            value.to_i == 1 # <BigDecimal:7b5bfe,'0.1E1',1(4)>
          else
            !! value
          end
        end

        # @override
        def string_to_time(string)
          return string unless string.is_a?(String)
          return nil if string.empty?
          return Time.now if string.index('CURRENT') == 0 # TODO seems very wrong

          super(string)
        end

        # @private
        def guess_date_or_time(value)
          return value if value.is_a? Date
          ( value && value.hour == 0 && value.min == 0 && value.sec == 0 ) ?
            Date.new(value.year, value.month, value.day) : value
        end

      end

    end
  end
end
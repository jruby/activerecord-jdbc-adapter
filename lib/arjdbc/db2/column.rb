module ArJdbc
  module DB2

    # @see ActiveRecord::ConnectionAdapters::JdbcColumn#column_types
    def self.column_selector
      [ /(db2|zos)/i, lambda { |config, column| column.extend(Column) } ]
    end

    # @see ActiveRecord::ConnectionAdapters::JdbcColumn
    module Column

      # @private
      def self.included(base)
        # NOTE: assumes a standalone DB2Column class
        class << base; include Cast; end
      end

      # @deprecated use `self.class.string_to_time`
      def self.cast_to_date_or_time(value)
        return value if value.is_a? Date
        return nil if value.blank?
        # https://github.com/jruby/activerecord-jdbc-adapter/commit/c225126e025df2e98ba3386c67e2a5bc5e5a73e6
        return Time.now if value =~ /^CURRENT/
        guess_date_or_time((value.is_a? Time) ? value : cast_to_time(value))
      rescue
        value
      end

      # @deprecated use `self.class.string_to_time` or `self.class.string_to_dummy_time`
      def self.cast_to_time(value)
        return value if value.is_a? Time
        # AS400 returns a 2 digit year, LUW returns a 4 digit year
        time = DateTime.parse(value).to_time rescue nil
        return nil unless time
        time_array = [time.year, time.month, time.day, time.hour, time.min, time.sec]
        time_array[0] ||= 2000; time_array[1] ||= 1; time_array[2] ||= 1;
        Time.send(ActiveRecord::Base.default_timezone, *time_array) rescue nil
      end

      # @deprecated
      # @private
      def self.guess_date_or_time(value)
        return value if value.is_a? Date
        ( value && value.hour == 0 && value.min == 0 && value.sec == 0 ) ?
          Date.new(value.year, value.month, value.day) : value
      end

      # @override
      def type_cast(value)
        return nil if value.nil? || value == 'NULL' || value =~ /^\s*NULL\s*$/i
        case type
        when :string    then value
        when :integer   then value.respond_to?(:to_i) ? value.to_i : (value ? 1 : 0)
        when :primary_key then value.respond_to?(:to_i) ? value.to_i : (value ? 1 : 0)
        when :float     then value.to_f
        when :date      then self.class.string_to_date(value)
        when :datetime  then self.class.string_to_time(value)
        when :timestamp then self.class.string_to_time(value)
        when :time      then self.class.string_to_dummy_time(value)
        # TODO AS400 stores binary strings in EBCDIC (CCSID 65535), need to convert back to ASCII
        else
          super
        end
      end

      # @override
      def type_cast_code(var_name)
        case type
        when :date      then "#{self.class.name}.string_to_date(#{var_name})"
        when :datetime  then "#{self.class.name}.string_to_time(#{var_name})"
        when :timestamp then "#{self.class.name}.string_to_time(#{var_name})"
        when :time      then "#{self.class.name}.string_to_dummy_time(#{var_name})"
        else
          super
        end
      end

      private

      def simplified_type(field_type)
        case field_type
        when /^decimal\(1\)$/i   then DB2.emulate_booleans? ? :boolean : :integer
        when /smallint/i         then DB2.emulate_booleans? ? :boolean : :integer
        when /boolean/i          then :boolean
        when /^real|double/i     then :float
        when /int|serial/i       then :integer
        # if a numeric column has no scale, lets treat it as an integer.
        # The AS400 rpg guys do this ALOT since they have no integer datatype ...
        when /decimal|numeric|decfloat/i
          extract_scale(field_type) == 0 ? :integer : :decimal
        when /timestamp/i        then :timestamp
        when /datetime/i         then :datetime
        when /time/i             then :time
        when /date/i             then :date
        # DB2 provides three data types to store these data objects as strings of up to 2 GB in size:
        #  Character large objects (CLOBs)
        #    Use the CLOB data type to store SBCS or mixed data, such as documents that contain
        #    single character set. Use this data type if your data is larger (or might grow larger)
        #    than the VARCHAR data type permits.
        #  Double-byte character large objects (DBCLOBs)
        #    Use the DBCLOB data type to store large amounts of DBCS data, such as documents that
        #    use a DBCS character set.
        #  Binary large objects (BLOBs)
        #    Use the BLOB data type to store large amounts of noncharacter data, such as pictures,
        #    voice, and mixed media.
        when /clob|text/i        then :text # handles DBCLOB
        when /^long varchar/i    then :text # :limit => 32700
        when /blob|binary/i      then :binary
        # varchar () for bit data, char () for bit data, long varchar for bit data
        when /for bit data/i     then :binary
        when /xml/i              then :xml
        when /graphic/i          then :graphic # vargraphic, long vargraphic
        when /rowid/i            then :rowid # rowid is a supported datatype on z/OS and i/5
        else
          super
        end
      end

      # Post process default value from JDBC into a Rails-friendly format (columns{-internal})
      def default_value(value)
        # IBM i (AS400) will return an empty string instead of null for no default
        return nil if value.blank?

        # string defaults are surrounded by single quotes
        return $1 if value =~ /^'(.*)'$/

        value
      end

      module Cast

        # @override
        def string_to_date(value)
          return nil unless value = current_date_time_parse(value)

          super
        end

        # @override
        def string_to_time(value)
          return nil unless value = current_date_time_parse(value)

          super
        end

        # @override
        def string_to_dummy_time(value)
          return nil unless value = current_date_time_parse(value)

          super
        end

        private

        def current_date_time_parse(value)
          return value unless value.is_a?(String)
          return nil if value.empty?
          return Time.now if value.index('CURRENT') == 0

          return value
        end

      end

    end
  end
end

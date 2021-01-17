module ArJdbc
  module MSSQL

    # @see ActiveRecord::ConnectionAdapters::JdbcColumn#column_types
    def self.column_selector
      [ /sqlserver|tds|Microsoft SQL/i, lambda { |config, column| column.extend(Column) } ]
    end

    # @see ActiveRecord::ConnectionAdapters::JdbcColumn
    module Column

      def self.included(base)
        # NOTE: assumes a standalone MSSQLColumn class
        class << base; include Cast; end
      end

      include LockMethods unless AR42

      # @override
      def simplified_type(field_type)
        case field_type
        when /int|bigint|smallint|tinyint/i           then :integer
        when /numeric/i                               then (@scale.nil? || @scale == 0) ? :integer : :decimal
        when /float|double|money|real|smallmoney/i    then :decimal
        when /datetime|smalldatetime/i                then :datetime
        when /timestamp/i                             then :timestamp
        when /time/i                                  then :time
        when /date/i                                  then :date
        when /text|ntext|xml/i                        then :text
        when /binary|image|varbinary/i                then :binary
        when /char|nchar|nvarchar|string|varchar/i    then (@limit == 1073741823 ? (@limit = nil; :text) : :string)
        when /bit/i                                   then :boolean
        when /uniqueidentifier/i                      then :string
        else
          super
        end
      end

      # @override
      def default_value(value)
        return $1 if value =~ /^\(N?'(.*)'\)$/ || value =~ /^\(\(?(.*?)\)?\)$/
        value
      end

      # @override
      def type_cast(value)
        return nil if value.nil?
        case type
        when :integer then ( value.is_a?(String) ? unquote(value) : (value || 0) ).to_i
        when :primary_key then value.respond_to?(:to_i) ? value.to_i : ((value && 1) || 0)
        when :decimal   then self.class.value_to_decimal(unquote(value))
        when :date      then self.class.string_to_date(value)
        when :datetime  then self.class.string_to_time(value)
        when :timestamp then self.class.string_to_time(value)
        when :time      then self.class.string_to_dummy_time(value)
        when :boolean   then value == true || (value =~ /^t(rue)?$/i) == 0 || unquote(value) == '1'
        when :binary    then unquote(value)
        else value
        end
      end

      # @override
      def extract_limit(sql_type)
        case sql_type
        when /^smallint/i
          2
        when /^int/i
          4
        when /^bigint/i
          8
        when /\(max\)/, /decimal/, /numeric/
          nil
        when /text|ntext|xml|binary|image|varbinary|bit/
          nil
        else
          super
        end
      end

      # #primary replacement that works on 4.2 as well
      # #columns will set @primary even when on AR 4.2
      def primary?; @primary end
      alias_method :is_primary, :primary?

      def identity?
        !! sql_type.downcase.index('identity')
      end
      # @deprecated
      alias_method :identity, :identity?
      alias_method :is_identity, :identity?

      # NOTE: these do not handle = equality as expected
      # see {#repair_special_columns}
      # (TEXT, NTEXT, and IMAGE data types are deprecated)
      # @private
      def special?
        unless defined? @special # /text|ntext|image|xml/i
          sql_type = @sql_type.downcase
          @special = !! ( sql_type.index('text') || sql_type.index('image') || sql_type.index('xml') )
        end
        @special
      end
      # @deprecated
      alias_method :special, :special?
      alias_method :is_special, :special?

      def is_utf8?
        !!( sql_type =~ /nvarchar|ntext|nchar/i )
      end

      private

      def unquote(value)
        value.to_s.sub(/\A\([\(\']?/, "").sub(/[\'\)]?\)\Z/, "")
      end

      # @deprecated no longer used
      def cast_to_time(value)
        return value if value.is_a?(Time)
        DateTime.parse(value).to_time rescue nil
      end

      # @deprecated no longer used
      def cast_to_date(value)
        return value if value.is_a?(Date)
        return Date.parse(value) rescue nil
      end

      # @deprecated no longer used
      def cast_to_datetime(value)
        if value.is_a?(Time)
          if value.year != 0 and value.month != 0 and value.day != 0
            return value
          else
            return Time.mktime(2000, 1, 1, value.hour, value.min, value.sec) rescue nil
          end
        end
        if value.is_a?(DateTime)
          begin
            # Attempt to convert back to a Time, but it could fail for dates significantly in the past/future.
            return Time.mktime(value.year, value.mon, value.day, value.hour, value.min, value.sec)
          rescue ArgumentError
            return value
          end
        end

        return cast_to_time(value) if value.is_a?(Date) or value.is_a?(String) rescue nil

        return value.is_a?(Date) ? value : nil
      end

      module Cast

        def string_to_date(value)
          return value unless value.is_a?(String)
          return nil if value.empty?

          date = fast_string_to_date(value)
          date ? date : Date.parse(value) rescue nil
        end

        def string_to_time(value)
          return value unless value.is_a?(String)
          return nil if value.empty?

          fast_string_to_time(value) || DateTime.parse(value).to_time rescue nil
        end

        ISO_TIME = /\A(\d\d)\:(\d\d)\:(\d\d)(\.\d+)?\z/

        def string_to_dummy_time(value)
          return value unless value.is_a?(String)
          return nil if value.empty?

          if value =~ ISO_TIME # "12:34:56.1234560"
            microsec = ($4.to_f * 1_000_000).round.to_i
            new_time 2000, 1, 1, $1.to_i, $2.to_i, $3.to_i, microsec
          else
            super(value)
          end
        end

        def string_to_binary(value)
          # this will only allow the adapter to insert binary data with a length
          # of 7K or less because of a SQL Server statement length policy ...
          "0x#{value.unpack("H*")}" # "0x#{value.unpack("H*")[0]}"
        end

        def binary_to_string(value)
          if value.respond_to?(:force_encoding) && value.encoding != Encoding::ASCII_8BIT
            value = value.force_encoding(Encoding::ASCII_8BIT)
          end
          value =~ /[^[:xdigit:]]/ ? value : [value].pack('H*')
        end

      end

    end
  end
end
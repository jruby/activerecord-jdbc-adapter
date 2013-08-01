module ArJdbc
  module PostgreSQL

    # @see ActiveRecord::ConnectionAdapters::JdbcColumn#column_types
    def self.column_selector
      [ /postgre/i, lambda { |cfg, column| column.extend(Column) } ]
    end

    # Column behavior based on PostgreSQL adapter in Rails.
    # @see ActiveRecord::ConnectionAdapters::JdbcColumn
    module Column

      def self.included(base)
        # NOTE: assumes a standalone PostgreSQLColumn class
        class << base
          include Cast
          attr_accessor :money_precision
        end
      end

      attr_accessor :array
      def array?; array; end # in case we remove the array reader

      # Extracts the value from a PostgreSQL column default definition.
      #
      # @override JdbcColumn#default_value
      # NOTE: based on `self.extract_value_from_default(default)` code
      def default_value(default)
        # This is a performance optimization for Ruby 1.9.2 in development.
        # If the value is nil, we return nil straight away without checking
        # the regular expressions. If we check each regular expression,
        # Regexp#=== will call NilClass#to_str, which will trigger
        # method_missing (defined by whiny nil in ActiveSupport) which
        # makes this method very very slow.
        return default unless default

        case default
          when /\A'(.*)'::(num|date|tstz|ts|int4|int8)range\z/m
            $1
          # Numeric types
          when /\A\(?(-?\d+(\.\d*)?\)?)\z/
            $1
          # Character types
          when /\A\(?'(.*)'::.*\b(?:character varying|bpchar|text)\z/m
            $1
          # Binary data types
          when /\A'(.*)'::bytea\z/m
            $1
          # Date/time types
          when /\A'(.+)'::(?:time(?:stamp)? with(?:out)? time zone|date)\z/
            $1
          when /\A'(.*)'::interval\z/
            $1
          # Boolean type
          when 'true'
            true
          when 'false'
            false
          # Geometric types
          when /\A'(.*)'::(?:point|line|lseg|box|"?path"?|polygon|circle)\z/
            $1
          # Network address types
          when /\A'(.*)'::(?:cidr|inet|macaddr)\z/
            $1
          # Bit string types
          when /\AB'(.*)'::"?bit(?: varying)?"?\z/
            $1
          # XML type
          when /\A'(.*)'::xml\z/m
            $1
          # Arrays
          when /\A'(.*)'::"?\D+"?\[\]\z/
            $1
          when /\AARRAY\[(.*)\](::\D+)?\z/
            "{#{$1.gsub(/'(.*?)'::[a-z]+(,)?\s?/, '\1\2')}}"
          # Hstore
          when /\A'(.*)'::hstore\z/
            $1
          # JSON
          when /\A'(.*)'::json\z/
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

      # Casts value (which is a String) to an appropriate instance.
      def type_cast(value)
        return if value.nil?
        return super if encoded? # respond_to?(:encoded?) only since AR-3.2

        # NOTE: we do not use OID::Type
        # @oid_type.type_cast value

        return value if array? # handled on the connection (JDBC) side

        case type
        when :hstore then self.class.string_to_hstore value
        when :json then self.class.string_to_json value
        when :cidr, :inet then self.class.string_to_cidr value
        when :macaddr then value
        when :tsvector then value
        when :datetime, :timestamp then self.class.string_to_time value
        else
          case sql_type
          when 'money'
            # Because money output is formatted according to the locale, there
            # are two cases to consider (note the decimal separators) :
            # (1) $12,345,678.12
            # (2) $12.345.678,12
            case value
            when /^-?\D+[\d,]+\.\d{2}$/ # (1)
              value.gsub!(/[^-\d.]/, '')
            when /^-?\D+[\d.]+,\d{2}$/ # (2)
              value.gsub!(/[^-\d,]/, '')
              value.sub!(/,/, '.')
            end
            self.class.value_to_decimal value
          when /^point/
            value.is_a?(String) ? self.class.string_to_point(value) : value
          when /^(bit|varbit)/
            value.is_a?(String) ? self.class.string_to_bit(value) : value
          when /(.*?)range$/
            return if value.nil? || value == 'empty'
            return value if value.is_a?(::Range)

            extracted = extract_bounds(value)

            case $1 # subtype
            when 'date' # :date
              from = self.class.value_to_date(extracted[:from])
              from -= 1.day if extracted[:exclude_start]
              to = self.class.value_to_date(extracted[:to])
            when 'num' # :decimal
              from = BigDecimal.new(extracted[:from].to_s)
              # FIXME: add exclude start for ::Range, same for timestamp ranges
              to = BigDecimal.new(extracted[:to].to_s)
            when 'ts', 'tstz' # :time
              from = self.class.string_to_time(extracted[:from])
              to = self.class.string_to_time(extracted[:to])
            when 'int4', 'int8' # :integer
              from = to_integer(extracted[:from]) rescue value ? 1 : 0
              from -= 1 if extracted[:exclude_start]
              to = to_integer(extracted[:to]) rescue value ? 1 : 0
            else
              return value
            end

            ::Range.new(from, to, extracted[:exclude_end])
          else super
          end
        end
      end if AR4_COMPAT

      private

      def extract_limit(sql_type)
        case sql_type
        when /^bigint/i; 8
        when /^smallint/i; 2
        when /^timestamp/i; nil
        else super
        end
      end

      # Extracts the scale from PostgreSQL-specific data types.
      def extract_scale(sql_type)
        # Money type has a fixed scale of 2.
        sql_type =~ /^money/ ? 2 : super
      end

      # Extracts the precision from PostgreSQL-specific data types.
      def extract_precision(sql_type)
        if sql_type == 'money'
          self.class.money_precision
        elsif sql_type =~ /timestamp/i
          $1.to_i if sql_type =~ /\((\d+)\)/
        else
          super
        end
      end

      # Maps PostgreSQL-specific data types to logical Rails types.
      def simplified_type(field_type)
        case field_type
          # Numeric and monetary types
        when /^(?:real|double precision)$/ then :float
          # Monetary types
        when 'money' then :decimal
          # Character types
        when /^(?:character varying|bpchar)(?:\(\d+\))?$/ then :string
          # Binary data types
        when 'bytea' then :binary
          # Date/time types
        when /^timestamp with(?:out)? time zone$/ then :datetime
        when 'interval' then :string
          # Geometric types
        when /^(?:point|line|lseg|box|"?path"?|polygon|circle)$/ then :string
          # Network address types
        when /^(?:cidr|inet|macaddr)$/ then :string
          # Bit strings
        when /^bit(?: varying)?(?:\(\d+\))?$/ then :string
          # XML type
        when 'xml' then :xml
          # tsvector type
        when 'tsvector' then :tsvector
          # Arrays
        when /^\D+\[\]$/ then :string
          # Object identifier types
        when 'oid' then :integer
          # UUID type
        when 'uuid' then :string
          # Small and big integer types
        when /^(?:small|big)int$/ then :integer
        # AR-JDBC added :
        when 'bool' then :boolean
        when 'char' then :string
        when 'serial' then :integer
          # Pass through all types that are not specific to PostgreSQL.
        else
          super
        end
      end

      # @private
      def simplified_type(field_type)
        case field_type
        # Numeric and monetary types
        when /^(?:real|double precision)$/ then :float
        # Monetary types
        when 'money' then :decimal
        when 'hstore' then :hstore
        when 'ltree' then :ltree
        # Network address types
        when 'inet' then :inet
        when 'cidr' then :cidr
        when 'macaddr' then :macaddr
        # Character types
        when /^(?:character varying|bpchar)(?:\(\d+\))?$/ then :string
        # Binary data types
        when 'bytea' then :binary
        # Date/time types
        when /^timestamp with(?:out)? time zone$/ then :datetime
        when /^interval(?:|\(\d+\))$/ then :string
        # Geometric types
        when /^(?:point|line|lseg|box|"?path"?|polygon|circle)$/ then :string
        # Bit strings
        when /^bit(?: varying)?(?:\(\d+\))?$/ then :string
        # XML type
        when 'xml' then :xml
        # tsvector type
        when 'tsvector' then :tsvector
        # Arrays
        when /^\D+\[\]$/ then :string
        # Object identifier types
        when 'oid' then :integer
        # UUID type
        when 'uuid' then :uuid
        # JSON type
        when 'json' then :json
        # Small and big integer types
        when /^(?:small|big)int$/ then :integer
        when /(num|date|tstz|ts|int4|int8)range$/
          field_type.to_sym
        # AR-JDBC added :
        when 'bool' then :boolean
        when 'char' then :string
        when 'serial' then :integer
        # Pass through all types that are not specific to PostgreSQL.
        else
          super
        end
      end if AR4_COMPAT

      # OID Type::Range helpers :

      def extract_bounds(value)
        f, t = value[1..-2].split(',')
        {
          :from => (value[1] == ',' || f == '-infinity') ? infinity(:negative => true) : f,
          :to   => (value[-2] == ',' || t == 'infinity') ? infinity : t,
          :exclude_start => (value[0] == '('), :exclude_end => (value[-1] == ')')
        }
      end if AR4_COMPAT

      def infinity(options = {})
        ::Float::INFINITY * (options[:negative] ? -1 : 1)
      end if AR4_COMPAT

      def to_integer(value)
        (value.respond_to?(:infinite?) && value.infinite?) ? value : value.to_i
      end if AR4_COMPAT

      # @note Based on *active_record/connection_adapters/postgresql/cast.rb* (4.0).
      module Cast

        def point_to_string(point)
          "(#{point[0]},#{point[1]})"
        end

        def string_to_point(string)
          if string[0] == '(' && string[-1] == ')'
            string = string[1...-1]
          end
          string.split(',').map { |v| Float(v) }
        end

        def string_to_time(string)
          return string unless String === string

          case string
          when  'infinity' then  1.0 / 0.0
          when '-infinity' then -1.0 / 0.0
          when / BC$/
            super("-" + string.sub(/ BC$/, ""))
          else
            super
          end
        end

        def string_to_bit(value)
          case value
          when /^[01]*$/      then value             # Bit-string notation
          when /^[0-9A-F]*$/i then value.hex.to_s(2) # Hexadecimal notation
          end
        end

        def string_to_bit(value)
          case value
          when /^0x/i
            value[2..-1].hex.to_s(2) # Hexadecimal notation
          else
            value # Bit-string notation
          end
        end if AR4_COMPAT

        def hstore_to_string(object)
          if Hash === object
            object.map { |k,v| "#{escape_hstore(k)}=>#{escape_hstore(v)}" }.join(',')
          else
            object
          end
        end

        def string_to_hstore(string)
          if string.nil?
            nil
          elsif String === string
            Hash[string.scan(HstorePair).map { |k,v|
              v = v.upcase == 'NULL' ? nil : v.gsub(/^"(.*)"$/,'\1').gsub(/\\(.)/, '\1')
              k = k.gsub(/^"(.*)"$/,'\1').gsub(/\\(.)/, '\1')
              [k,v]
            }]
          else
            string
          end
        end

        def json_to_string(object)
          if Hash === object
            ActiveSupport::JSON.encode(object)
          else
            object
          end
        end

        def array_to_string(value, column, adapter, should_be_quoted = false)
          casted_values = value.map do |val|
            if String === val
              if val == "NULL"
                "\"#{val}\""
              else
                quote_and_escape(adapter.type_cast(val, column, true))
              end
            else
              adapter.type_cast(val, column, true)
            end
          end
          "{#{casted_values.join(',')}}"
        end

        def range_to_string(object)
          from = object.begin.respond_to?(:infinite?) && object.begin.infinite? ? '' : object.begin
          to   = object.end.respond_to?(:infinite?) && object.end.infinite? ? '' : object.end
          "[#{from},#{to}#{object.exclude_end? ? ')' : ']'}"
        end

        def string_to_json(string)
          if String === string
            ActiveSupport::JSON.decode(string)
          else
            string
          end
        end

        def string_to_cidr(string)
          if string.nil?
            nil
          elsif String === string
            IPAddr.new(string)
          else
            string
          end
        end

        def cidr_to_string(object)
          if IPAddr === object
            "#{object.to_s}/#{object.instance_variable_get(:@mask_addr).to_s(2).count('1')}"
          else
            object
          end
        end

        # NOTE: not used - we get "parsed" array value from connection
        #def string_to_array(string, oid)
        #  parse_pg_array(string).map { |val| oid.type_cast val }
        #end

        private

        # @private
        HstorePair = begin
          quoted_string = /"[^"\\]*(?:\\.[^"\\]*)*"/
          unquoted_string = /(?:\\.|[^\s,])[^\s=,\\]*(?:\\.[^\s=,\\]*|=[^,>])*/
          /(#{quoted_string}|#{unquoted_string})\s*=>\s*(#{quoted_string}|#{unquoted_string})/
        end

        def escape_hstore(value)
          if value.nil?
            'NULL'
          else
            if value == ""
              '""'
            else
              '"%s"' % value.to_s.gsub(/(["\\])/, '\\\\\1')
            end
          end
        end

        def quote_and_escape(value)
          case value
          when "NULL"
            value
          else
            "\"#{value.gsub(/(["\\])/, '\\\\\1')}\""
          end
        end

      end

    end
  end
end

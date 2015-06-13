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

    # Column behavior based on PostgreSQL adapter in Rails.
    # @see ActiveRecord::ConnectionAdapters::JdbcColumn
    module Column

      attr_accessor :array
      alias array? array

      def initialize(name, default, cast_type, sql_type = nil, null = true, default_function = nil,
        oid = nil, adapter = nil) # added arguments
        if sql_type.to_s[-2, 2] == '[]'
          @array = true
          super(name, default, cast_type, sql_type[0..-3], null)
        else
          @array = false
          super(name, default, cast_type, sql_type, null)
        end

        @oid = oid # used on Java side - expects @oid on Column instances
        #@adapter = adapter

        @default_function = default_function
      end

    end if AR42

    # @private (AR < 4.2 version) documented above
    module Column

      def initialize(name, default, oid_type = nil, sql_type = nil, null = true,
          fmod = nil, adapter = nil) # added due resolving #oid_type
        if oid_type.is_a?(Integer) # the "main" if branch (on AR 4.x)
          @oid = oid_type; @fmod = fmod; @adapter = adapter # see Column#oid_type
        elsif oid_type.respond_to?(:type_cast) # MRI compatibility
          @oid_type = oid_type; # @fmod = fmod; @adapter = adapter
        else # NOTE: AR <= 3.2 : (name, default, sql_type = nil, null = true)
          null, sql_type, oid_type = !! sql_type, oid_type, nil
        end
        if sql_type.to_s[-2, 2] == '[]' && AR40
          @array = true if respond_to?(:array)
          super(name, default, sql_type[0..-3], null)
        else
          @array = false if respond_to?(:array)
          super(name, default, sql_type, null)
        end

        @default_function = extract_default_function(@default, default)
      end

      def self.included(base)
        # NOTE: assumes a standalone PostgreSQLColumn class
        base_meta = class << base; self end
        base_meta.send :attr_accessor, :money_precision

        # Loads pg_array_parser if available. String parsing can be
        # performed quicker by a native extension, which will not create
        # a large amount of Ruby objects that will need to be garbage
        # collected. pg_array_parser has a C and Java extension
        begin
          require 'pg_array_parser'
          base_meta.send :include, PgArrayParser
        rescue LoadError
          if AR42
            require 'active_record/connection_adapters/postgresql/array_parser'
          else
            require 'arjdbc/postgresql/base/array_parser'
          end
          base_meta.send :include, ActiveRecord::ConnectionAdapters::PostgreSQL::ArrayParser
        end if AR40

        base_meta.send :include, Cast

        base.send :include, ColumnHelpers
      end

      if AR40 && ! AR42

      # @private
      def oid_type
        @oid_type ||= begin
          raise "oid not defined" unless oid = (@oid ||= nil)
          @adapter.get_oid_type(oid.to_i, @fmod.to_i, name)
        end
      end

      # @private
      def accessor; oid_type.accessor end

      end

      ( attr_accessor :array; def array?; array; end ) if AR40

      def number?; !array && super end if AR40
      def text?; !array && super end if AR40

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
          when /\A\(?(-?\d+(\.\d*)?\)?(::bigint)?)\z/
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
          # JSONB
          when /\A'(.*)'::jsonb\z/
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
      # @private
      def type_cast(value) # AR < 4.0 version
        return if value.nil?
        return super if respond_to?(:encoded?) && encoded? # since AR-3.2

        case sql_type
        when 'money'
          self.class.string_to_money(value)
        else super
        end
      end

      # Casts value (which is a String) to an appropriate instance.
      def type_cast(value, type = false) # AR >= 4.0 version
        return if value.nil?
        return super(value) if encoded?

        # NOTE: we do not use OID::Type
        # @oid_type.type_cast value

        return self.class.string_to_array(value, self) if array? && type == false

        case type ||= self.type
        when :hstore then self.class.string_to_hstore value
        when :json then self.class.string_to_json value
        when :jsonb then self.class.string_to_json value
        when :cidr, :inet then self.class.string_to_cidr value
        when :macaddr then value
        when :tsvector then value
        when :datetime, :timestamp then self.class.string_to_time value
        else
          if ( sql_type = self.sql_type.to_s ) == 'money'
            self.class.string_to_money(value)
          elsif sql_type[0, 5] == 'point'
            value.is_a?(String) ? self.class.string_to_point(value) : value
          elsif sql_type[0, 3] == 'bit' || sql_type[0, 6] == 'varbit'
            value.is_a?(String) ? self.class.string_to_bit(value) : value
          elsif sql_type[-5, 5] == 'range'
            return if value.nil? || value == 'empty'
            return value if value.is_a?(::Range)

            extracted = extract_bounds(value)

            case sql_type[0...-5] # range sub-type
            when 'date' # :date
              from = self.class.value_to_date(extracted[:from])
              from += 1.day if extracted[:exclude_start]
              to = self.class.value_to_date(extracted[:to])
            when 'num' # :decimal
              from = ::BigDecimal.new(extracted[:from].to_s)
              # FIXME: add exclude start for ::Range, same for timestamp ranges
              to = ::BigDecimal.new(extracted[:to].to_s)
            when 'ts', 'tstz' # :time
              from = self.class.string_to_time(extracted[:from])
              to = self.class.string_to_time(extracted[:to])
            when 'int4', 'int8' # :integer
              from = extracted[:from]
              unless (from.respond_to?(:infinite?) && from.infinite?)
                from = from.respond_to?(:to_i) ? from.to_i : ( value ? 1 : 0 )
              end
              from += 1 if extracted[:exclude_start]
              to = extracted[:to]
              unless (to.respond_to?(:infinite?) && to.infinite?)
                to = to.respond_to?(:to_i) ? to.to_i : ( value ? 1 : 0 )
              end
            else
              return value
            end

            ::Range.new(from, to, extracted[:exclude_end])
          else
             super(value)
          end
        end
      end if AR40

      private

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
        when 'jsonb' then :jsonb
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
      end if AR40

      # OID Type::Range helpers :

      def extract_bounds(value)
        f, t = value[1..-2].split(',')
        {
          :from => (value[1] == ',' || f == '-infinity') ? infinity(:negative => true) : f,
          :to   => (value[-2] == ',' || t == 'infinity') ? infinity : t,
          :exclude_start => (value[0] == '('), :exclude_end => (value[-1] == ')')
        }
      end if AR40

      def infinity(options = {})
        ::Float::INFINITY * (options[:negative] ? -1 : 1)
      end if AR40

      private

      # TODO marshaling worked in 1.3.7 ,,, got broken in 1.3.8 (due @adapter)
      # but the fix introduced in 1.3.10 causes backwards (1.3) incompatibility
      # ... for now should be fine - there's likely more refactoring to happen!

      def marshal_dump
        # NOTE: disabled oid_type ... due range warnings (maybe they're fine) :
        # unknown OID 3904: failed to recognize type of 'int4_range'. It will be treated as String.
        #oid_type if respond_to?(:oid_type)
        @adapter = nil
        instance_variables.map { |var| [ var, instance_variable_get(var) ] }
      end

      def marshal_load(data)
        data.each { |pair| instance_variable_set( pair[0], pair[1] ) }
      end

      # @note Based on *active_record/connection_adapters/postgresql/cast.rb* (4.0).
      module Cast

        def string_to_money(string)
          return string unless String === string

          # Because money output is formatted according to the locale, there
          # are two cases to consider (note the decimal separators) :
          # (1) $12,345,678.12
          # (2) $12.345.678,12
          # Negative values are represented as follows:
          #  (3) -$2.55
          #  (4) ($2.55)
          string = string.sub(/^\((.+)\)$/, '-\1') # (4)
          case string
          when /^-?\D+[\d,]+\.\d{2}$/ # (1)
            string.gsub!(/[^-\d.]/, '')
          when /^-?\D+[\d.]+,\d{2}$/ # (2)
            string.gsub!(/[^-\d,]/, '')
            string.sub!(/,/, '.')
          end
          value_to_decimal string
        end

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
            super("-#{string.sub(/ BC$/, "")}")
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
        end if AR40

        def hstore_to_string(object, array_member = false)
          if Hash === object
            string = object.map { |k, v| "#{escape_hstore(k)}=>#{escape_hstore(v)}" }.join(',')
            string = escape_hstore(string) if array_member
            string
          else
            object
          end
        end

        def string_to_hstore(string)
          if string.nil?
            nil
          elsif String === string
            Hash[string.scan(HstorePair).map { |k, v|
              v = v.upcase == 'NULL' ? nil : v.gsub(/\A"(.*)"\Z/m,'\1').gsub(/\\(.)/, '\1')
              k = k.gsub(/\A"(.*)"\Z/m,'\1').gsub(/\\(.)/, '\1')
              [k, v]
            }]
          else
            string
          end
        end

        def json_to_string(object)
          if Hash === object || Array === object
            ActiveSupport::JSON.encode(object)
          else
            object
          end
        end

        def array_to_string(value, column, adapter)
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
            begin
              IPAddr.new(string)
            rescue ArgumentError
              nil
            end
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

        # @note Only used for default values - we get a "parsed" array from JDBC.
        def string_to_array(string, column_or_oid)
          return string unless String === string
          parse_pg_array(string).map { |val| type_cast_array(column_or_oid, val) }
        end

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

        ARRAY_ESCAPE = "\\" * 2 * 2 # escape the backslash twice for PG arrays

        def quote_and_escape(value)
          case value
          when "NULL", Numeric
            value
          else
            value = value.gsub(/\\/, ARRAY_ESCAPE)
            value.gsub!(/"/,"\\\"")
            "\"#{value}\""
          end
        end

        def type_cast_array(oid, value)
          if ::Array === value
            value.map { |item| type_cast_array(oid, item) }
          else
            if oid.is_a?(Column)
              oid.type_cast value, oid.type # column.type
            else
              oid.type_cast value
            end
          end
        end

      end

    end unless AR42
  end
end

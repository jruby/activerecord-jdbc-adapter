ArJdbc.load_java_part :PostgreSQL

require 'ipaddr'
require 'arjdbc/postgresql/column_cast'
require 'arjdbc/postgresql/explain_support'

module ArJdbc
  module PostgreSQL
    
    AR4_COMPAT = ::ActiveRecord::VERSION::MAJOR > 3 unless const_defined?(:AR4_COMPAT) # :nodoc:
    
    def self.extended(base)
      base.configure_connection
    end

    def self.column_selector
      [ /postgre/i, lambda { |cfg, column| column.extend(::ArJdbc::PostgreSQL::Column) } ]
    end

    def self.jdbc_connection_class
      ::ActiveRecord::ConnectionAdapters::PostgreSQLJdbcConnection
    end

    def set_client_encoding(encoding)
      ActiveRecord::Base.logger.warn "client_encoding is set by the driver and should not be altered, ('#{encoding}' ignored)"
      ActiveRecord::Base.logger.debug "Set the 'allowEncodingChanges' driver property (e.g. using config[:properties]) if you need to override the client encoding when doing a copy."
    end

    # Configures the encoding, verbosity, schema search path, and time zone of the connection.
    # This is called by #connect and should not be called manually.
    def configure_connection
      #if encoding = config[:encoding]
        # The client_encoding setting is set by the driver and should not be altered.
        # If the driver detects a change it will abort the connection.
        # see http://jdbc.postgresql.org/documentation/91/connect.html
        # self.set_client_encoding(encoding)
      #end
      self.client_min_messages = config[:min_messages] || 'warning'
      self.schema_search_path = config[:schema_search_path] || config[:schema_order]

      # Use standard-conforming strings if available so we don't have to do the E'...' dance.
      set_standard_conforming_strings

      # If using Active Record's time zone support configure the connection to return
      # TIMESTAMP WITH ZONE types in UTC.
      # (SET TIME ZONE does not use an equals sign like other SET variables)
      if ActiveRecord::Base.default_timezone == :utc
        execute("SET time zone 'UTC'", 'SCHEMA')
      elsif defined?(@local_tz) && @local_tz
        execute("SET time zone '#{@local_tz}'", 'SCHEMA')
      end # if defined? ActiveRecord::Base.default_timezone

      # SET statements from :variables config hash
      # http://www.postgresql.org/docs/8.3/static/sql-set.html
      (config[:variables] || {}).map do |k, v|
        if v == ':default' || v == :default
          # Sets the value to the global or compile default
          execute("SET SESSION #{k.to_s} TO DEFAULT", 'SCHEMA')
        elsif ! v.nil?
          execute("SET SESSION #{k.to_s} TO #{quote(v)}", 'SCHEMA')
        end
      end
    end

    # constants taken from postgresql_adapter in rails project
    ADAPTER_NAME = 'PostgreSQL'.freeze

    def adapter_name # :nodoc:
      ADAPTER_NAME
    end

    def self.arel2_visitors(config)
      {
        'postgresql' => ::Arel::Visitors::PostgreSQL,
        'jdbcpostgresql' => ::Arel::Visitors::PostgreSQL,
        'pg' => ::Arel::Visitors::PostgreSQL
      }
    end
    
    def new_visitor(config = nil)
      visitor = ::Arel::Visitors::PostgreSQL
      ( prepared_statements? ? visitor : bind_substitution(visitor) ).new(self)
    end if defined? ::Arel::Visitors::PostgreSQL
    
    # @see #bind_substitution
    class BindSubstitution < Arel::Visitors::PostgreSQL # :nodoc:
      include Arel::Visitors::BindVisitor
    end if defined? Arel::Visitors::BindVisitor

    def postgresql_version
      @postgresql_version ||=
        begin
          value = select_value('SELECT version()')
          if value =~ /PostgreSQL (\d+)\.(\d+)\.(\d+)/
            ($1.to_i * 10000) + ($2.to_i * 100) + $3.to_i
          else
            0
          end
        end
    end
    
    def use_insert_returning?
      if ( @use_insert_returning ||= nil ).nil?
        @use_insert_returning = supports_insert_with_returning?
      end
      @use_insert_returning
    end
    
    # column behavior based on postgresql_adapter in rails
    module Column
      
      def self.included(base)
        class << base
          include ArJdbc::PostgreSQL::Column::Cast
          # include ArJdbc::PostgreSQL::Column::ArrayParser
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
            if value.is_a?(String)
              self.class.string_to_point value
            else
              value
            end
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
          # Pass through all types that are not specific to PostgreSQL.
        else
          super
        end
      end
      
      def simplified_type(field_type) # :nodoc:
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
      
    end # Column

    ActiveRecordError = ::ActiveRecord::ActiveRecordError # :nodoc:
    
    # Maps logical Rails types to PostgreSQL-specific data types.
    def type_to_sql(type, limit = nil, precision = nil, scale = nil)
      case type.to_sym
      when :'binary'
        # PostgreSQL doesn't support limits on binary (bytea) columns.
        # The hard limit is 1Gb, because of a 32-bit size field, and TOAST.
        case limit
        when nil, 0..0x3fffffff; super(type, nil, nil, nil)
        else raise(ActiveRecordError, "No binary type has byte size #{limit}.")
        end
      when :'text'
        # PostgreSQL doesn't support limits on text columns.
        # The hard limit is 1Gb, according to section 8.3 in the manual.
        case limit
        when nil, 0..0x3fffffff; super(type, nil, nil, nil)
        else raise(ActiveRecordError, "The limit on text can be at most 1GB - 1byte.")
        end
      when :'integer'
        return 'integer' unless limit

        case limit
          when 1, 2; 'smallint'
          when 3, 4; 'integer'
          when 5..8; 'bigint'
          else raise(ActiveRecordError, "No integer type has byte size #{limit}. Use a numeric with precision 0 instead.")
        end
      when :'datetime'
        return super unless precision

        case precision
          when 0..6; "timestamp(#{precision})"
          else raise(ActiveRecordError, "No timestamp type has precision of #{precision}. The allowed range of precision is from 0 to 6")
        end
      else
        super
      end
    end

    def type_cast(value, column, array_member = false)
      return super unless column

      case value
      when String
        return super(value, column) unless 'bytea' == column.sql_type
        value # { :value => value, :format => 1 }
      when Array
        return super(value, column) unless column.array
        column_class = ::ActiveRecord::ConnectionAdapters::PostgreSQLColumn
        column_class.array_to_string(value, column, self)
      when NilClass
        if column.array && array_member
          'NULL'
        elsif column.array
          value
        else
          super(value, column)
        end
      when Hash
        case column.sql_type
        when 'hstore'
          column_class = ::ActiveRecord::ConnectionAdapters::PostgreSQLColumn
          column_class.hstore_to_string(value)
        when 'json'
          column_class = ::ActiveRecord::ConnectionAdapters::PostgreSQLColumn
          column_class.json_to_string(value)
        else super(value, column)
        end
      when IPAddr
        return super unless column.sql_type == 'inet' || column.sql_type == 'cidr'
        column_class = ::ActiveRecord::ConnectionAdapters::PostgreSQLColumn
        column_class.cidr_to_string(value)
      else
        super(value, column)
      end
    end if AR4_COMPAT
    
    NATIVE_DATABASE_TYPES = {
      :primary_key => "serial primary key",
      :string => { :name => "character varying", :limit => 255 },
      :text => { :name => "text" },
      :integer => { :name => "integer" },
      :float => { :name => "float" },
      :decimal => { :name => "decimal" },
      :datetime => { :name => "timestamp" },
      :timestamp => { :name => "timestamp" },
      :time => { :name => "time" },
      :date => { :name => "date" },
      :binary => { :name => "bytea" },
      :boolean => { :name => "boolean" },
      :xml => { :name => "xml" },
    }
    
    NATIVE_DATABASE_TYPES.update({
      :tsvector => { :name => "tsvector" },
      :hstore => { :name => "hstore" },
      :inet => { :name => "inet" },
      :cidr => { :name => "cidr" },
      :macaddr => { :name => "macaddr" },
      :uuid => { :name => "uuid" },
      :json => { :name => "json" },
      :ltree => { :name => "ltree" },
      # ranges :
      :daterange => { :name => "daterange" },
      :numrange => { :name => "numrange" },
      :tsrange => { :name => "tsrange" },
      :tstzrange => { :name => "tstzrange" },
      :int4range => { :name => "int4range" },
      :int8range => { :name => "int8range" },
    }) if AR4_COMPAT
    
    def native_database_types
      NATIVE_DATABASE_TYPES
    end
    
    # Adds `:array` option to the default set provided by the AbstractAdapter
    def prepare_column_options(column, types)
      spec = super
      spec[:array] = 'true' if column.respond_to?(:array) && column.array
      spec
    end if AR4_COMPAT

    # Adds `:array` as a valid migration key
    def migration_keys
      super + [:array]
    end if AR4_COMPAT
    
    def add_column_options!(sql, options)
      if options[:array] || options[:column].try(:array)
        sql << '[]'
      end

      column = options.fetch(:column) { return super }
      if column.type == :uuid && options[:default] =~ /\(\)/
        sql << " DEFAULT #{options[:default]}"
      else
        super
      end
    end if AR4_COMPAT
    
    # Enable standard-conforming strings if available.
    def set_standard_conforming_strings # native adapter API compatibility
      self.standard_conforming_strings=(true)
    end
    
    # Enable standard-conforming strings if available.
    def standard_conforming_strings=(enable)
      client_min_messages = self.client_min_messages
      begin
        self.client_min_messages = 'panic'
        value = enable ? "on" : "off"
        execute("SET standard_conforming_strings = #{value}", 'SCHEMA')
        @standard_conforming_strings = ( value == "on" )
      rescue
        @standard_conforming_strings = :unsupported
      ensure
        self.client_min_messages = client_min_messages
      end
    end

    def standard_conforming_strings? # :nodoc:
      if @standard_conforming_strings.nil?
        client_min_messages = self.client_min_messages
        begin
          self.client_min_messages = 'panic'
          value = select_one('SHOW standard_conforming_strings', 'SCHEMA')['standard_conforming_strings']
          @standard_conforming_strings = ( value == "on" )
        rescue
          @standard_conforming_strings = :unsupported
        ensure
          self.client_min_messages = client_min_messages
        end
      end
      @standard_conforming_strings == true # return false if :unsupported
    end

    # Does PostgreSQL support migrations?
    def supports_migrations? # :nodoc:
      true
    end

    # Does PostgreSQL support finding primary key on non-Active Record tables?
    def supports_primary_key? # :nodoc:
      true
    end
    
    # Does PostgreSQL support standard conforming strings?
    def supports_standard_conforming_strings? # :nodoc:
      standard_conforming_strings?
      @standard_conforming_strings != :unsupported
    end

    def supports_hex_escaped_bytea? # :nodoc:
      postgresql_version >= 90000
    end

    def supports_insert_with_returning? # :nodoc:
      postgresql_version >= 80200
    end

    def supports_ddl_transactions? # :nodoc:
      true
    end

    def supports_transaction_isolation? # :nodoc:
      true
    end
    
    def supports_index_sort_order? # :nodoc:
      true
    end
    
    # Range datatypes weren't introduced until PostgreSQL 9.2
    def supports_ranges? # :nodoc:
      postgresql_version >= 90200
    end if AR4_COMPAT
    
    def supports_savepoints? # :nodoc:
      true
    end
    
    def supports_transaction_isolation?(level = nil)
      true
    end
    
    def create_savepoint
      execute("SAVEPOINT #{current_savepoint_name}")
    end

    def rollback_to_savepoint
      execute("ROLLBACK TO SAVEPOINT #{current_savepoint_name}")
    end

    def release_savepoint
      execute("RELEASE SAVEPOINT #{current_savepoint_name}")
    end
    
    def supports_extensions? # :nodoc:
      postgresql_version >= 90200
    end # NOTE: only since AR-4.0 but should not hurt on other versions
    
    def enable_extension(name)
      execute("CREATE EXTENSION IF NOT EXISTS \"#{name}\"")
    end

    def disable_extension(name)
      execute("DROP EXTENSION IF EXISTS \"#{name}\" CASCADE")
    end

    def extension_enabled?(name)
      if supports_extensions?
        rows = select_rows("SELECT EXISTS(SELECT * FROM pg_available_extensions WHERE name = '#{name}' AND installed_version IS NOT NULL)", 'SCHEMA')
        rows.first.first
      end
    end

    def extensions
      if supports_extensions?
        rows = select_rows "SELECT extname from pg_extension", "SCHEMA"
        rows.map { |row| row.first }
      else
        []
      end
    end
    
    # Set the authorized user for this session
    def session_auth=(user)
      execute "SET SESSION AUTHORIZATION #{user}"
    end
    
    # Returns the configured supported identifier length supported by PostgreSQL,
    # or report the default of 63 on PostgreSQL 7.x.
    def table_alias_length
      @table_alias_length ||= (
        postgresql_version >= 80000 ? 
          select_one('SHOW max_identifier_length')['max_identifier_length'].to_i : 
            63
      )
    end

    def default_sequence_name(table_name, pk = nil)
      default_pk, default_seq = pk_and_sequence_for(table_name)
      default_seq || "#{table_name}_#{pk || default_pk || 'id'}_seq"
    end

    # Resets sequence to the max value of the table's pk if present.
    def reset_pk_sequence!(table, pk = nil, sequence = nil) #:nodoc:
      if ! pk || ! sequence
        default_pk, default_sequence = pk_and_sequence_for(table)
        pk ||= default_pk; sequence ||= default_sequence
      end
      if pk && sequence
        quoted_sequence = quote_column_name(sequence)

        select_value <<-end_sql, 'Reset Sequence'
          SELECT setval('#{quoted_sequence}', (SELECT COALESCE(MAX(#{quote_column_name pk})+(SELECT increment_by FROM #{quoted_sequence}), (SELECT min_value FROM #{quoted_sequence})) FROM #{quote_table_name(table)}), false)
        end_sql
      end
    end

    # Find a table's primary key and sequence.
    def pk_and_sequence_for(table) #:nodoc:
      # First try looking for a sequence with a dependency on the
      # given table's primary key.
      result = select(<<-end_sql, 'PK and Serial Sequence')[0]
          SELECT attr.attname, seq.relname
          FROM pg_class      seq,
               pg_attribute  attr,
               pg_depend     dep,
               pg_namespace  name,
               pg_constraint cons
          WHERE seq.oid           = dep.objid
            AND seq.relkind       = 'S'
            AND attr.attrelid     = dep.refobjid
            AND attr.attnum       = dep.refobjsubid
            AND attr.attrelid     = cons.conrelid
            AND attr.attnum       = cons.conkey[1]
            AND cons.contype      = 'p'
            AND dep.refobjid      = '#{quote_table_name(table)}'::regclass
        end_sql

      if result.nil? || result.empty?
        # If that fails, try parsing the primary key's default value.
        # Support the 7.x and 8.0 nextval('foo'::text) as well as
        # the 8.1+ nextval('foo'::regclass).
        result = select(<<-end_sql, 'PK and Custom Sequence')[0]
            SELECT attr.attname,
              CASE
                WHEN split_part(def.adsrc, '''', 2) ~ '.' THEN
                  substr(split_part(def.adsrc, '''', 2),
                         strpos(split_part(def.adsrc, '''', 2), '.')+1)
                ELSE split_part(def.adsrc, '''', 2)
              END as relname
            FROM pg_class       t
            JOIN pg_attribute   attr ON (t.oid = attrelid)
            JOIN pg_attrdef     def  ON (adrelid = attrelid AND adnum = attnum)
            JOIN pg_constraint  cons ON (conrelid = adrelid AND adnum = conkey[1])
            WHERE t.oid = '#{quote_table_name(table)}'::regclass
              AND cons.contype = 'p'
              AND def.adsrc ~* 'nextval'
          end_sql
      end

      [ result['attname'], result['relname'] ]
    rescue
      nil
    end
    
    def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [])
      unless pk
        # Extract the table from the insert sql. Yuck.
        table_ref = extract_table_ref_from_insert_sql(sql)
        pk = primary_key(table_ref) if table_ref
      end

      if pk && use_insert_returning? # && id_value.nil?
        select_value("#{to_sql(sql, binds)} RETURNING #{quote_column_name(pk)}")
      else
        execute(sql, name, binds) # super
        unless id_value
          table_ref ||= extract_table_ref_from_insert_sql(sql)
          # If neither PK nor sequence name is given, look them up.
          if table_ref && ! ( pk ||= primary_key(table_ref) ) && ! sequence_name
            pk, sequence_name = pk_and_sequence_for(table_ref)
          end
          # If a PK is given, fallback to default sequence name.
          # Don't fetch last insert id for a table without a PK.
          if pk && sequence_name ||= default_sequence_name(table_ref, pk)
            id_value = last_insert_id(table_ref, sequence_name)
          end
        end
        id_value
      end
    end
    
    # taken from rails postgresql_adapter.rb
    def sql_for_insert(sql, pk, id_value, sequence_name, binds)
      unless pk
        table_ref = extract_table_ref_from_insert_sql(sql)
        pk = primary_key(table_ref) if table_ref
      end

      sql = "#{sql} RETURNING #{quote_column_name(pk)}" if pk

      [ sql, binds ]
    end
    
    def primary_key(table)
      result = select(<<-end_sql, 'SCHEMA').first
        SELECT attr.attname
        FROM pg_attribute attr
        INNER JOIN pg_constraint cons ON attr.attrelid = cons.conrelid AND attr.attnum = cons.conkey[1]
        WHERE cons.contype = 'p'
          AND cons.conrelid = '#{quote_table_name(table)}'::regclass
      end_sql
      
      result && result["attname"]
      # pk_and_sequence = pk_and_sequence_for(table)
      # pk_and_sequence && pk_and_sequence.first
    end
    
    # Returns an array of schema names.
    def schema_names
      select_values(
        "SELECT nspname FROM pg_namespace" <<
        " WHERE nspname !~ '^pg_.*' AND nspname NOT IN ('information_schema')" <<
        " ORDER by nspname;", 
      'SCHEMA')
    end
        
    # Returns true if schema exists.
    def schema_exists?(name)
      select_value("SELECT COUNT(*) FROM pg_namespace WHERE nspname = '#{name}'", 'SCHEMA').to_i > 0
    end
    
    # Returns the current schema name.
    def current_schema
      select_value('SELECT current_schema', 'SCHEMA')
    end
    
    # current database name
    def current_database
      select_value('SELECT current_database()', 'SCHEMA')
    end

    # Returns the current database encoding format.
    def encoding
      select_value(
        "SELECT pg_encoding_to_char(pg_database.encoding)" << 
        " FROM pg_database" << 
        " WHERE pg_database.datname LIKE '#{current_database}'", 
      'SCHEMA')
    end

    # Returns the current database collation.
    def collation
      select_value(
        "SELECT pg_database.datcollate" << 
        " FROM pg_database" << 
        " WHERE pg_database.datname LIKE '#{current_database}'",
      'SCHEMA')
    end
    
    # Returns the current database ctype.
    def ctype
      select_value(
        "SELECT pg_database.datctype FROM pg_database WHERE pg_database.datname LIKE '#{current_database}'",
      'SCHEMA')
    end

    # Returns the active schema search path.
    def schema_search_path
      @schema_search_path ||= select_value('SHOW search_path', 'SCHEMA')
    end
    
    # Sets the schema search path to a string of comma-separated schema names.
    # Names beginning with $ have to be quoted (e.g. $user => '$user').
    # See: http://www.postgresql.org/docs/current/static/ddl-schemas.html
    #
    # This should be not be called manually but set in database.yml.
    def schema_search_path=(schema_csv)
      if schema_csv
        execute "SET search_path TO #{schema_csv}"
        @schema_search_path = schema_csv
      end
    end

    # take id from result of insert query
    def last_inserted_id(result)
      if result.is_a? Integer
        result
      else
        result.first.first[1]
      end
    end

    def last_insert_id(table, sequence_name = nil)
      sequence_name = table if sequence_name.nil? # AR-4.0 1 argument
      Integer(select_value("SELECT currval('#{sequence_name}')", 'SQL'))
    end
    
    def recreate_database(name, options = {})
      drop_database(name)
      create_database(name, options)
    end
    
    # Create a new PostgreSQL database. Options include <tt>:owner</tt>, <tt>:template</tt>,
    # <tt>:encoding</tt>, <tt>:collation</tt>, <tt>:ctype</tt>,
    # <tt>:tablespace</tt>, and <tt>:connection_limit</tt> (note that MySQL uses
    # <tt>:charset</tt> while PostgreSQL uses <tt>:encoding</tt>).
    #
    # Example:
    # create_database config[:database], config
    # create_database 'foo_development', encoding: 'unicode'
    def create_database(name, options = {})
      options = { :encoding => 'utf8' }.merge!(options.symbolize_keys)

      option_string = options.sum do |key, value|
        case key
        when :owner
          " OWNER = \"#{value}\""
        when :template
          " TEMPLATE = \"#{value}\""
        when :encoding
          " ENCODING = '#{value}'"
        when :collation
          " LC_COLLATE = '#{value}'"
        when :ctype
          " LC_CTYPE = '#{value}'"
        when :tablespace
          " TABLESPACE = \"#{value}\""
        when :connection_limit
          " CONNECTION LIMIT = #{value}"
        else
          ""
        end
      end

      execute "CREATE DATABASE #{quote_table_name(name)}#{option_string}"
    end

    def drop_database(name)
      execute "DROP DATABASE IF EXISTS #{quote_table_name(name)}"
    end

    # Creates a schema for the given schema name.
    def create_schema(schema_name, pg_username = nil)
      if pg_username.nil? # AR 4.0 compatibility - accepts only single argument
        execute "CREATE SCHEMA #{schema_name}"
      else
        execute("CREATE SCHEMA \"#{schema_name}\" AUTHORIZATION \"#{pg_username}\"")
      end
    end

    # Drops the schema for the given schema name.
    def drop_schema schema_name
      execute "DROP SCHEMA #{schema_name} CASCADE"
    end

    def all_schemas
      select('SELECT nspname FROM pg_namespace').map { |row| row["nspname"] }
    end

    def structure_dump
      database = @config[:database]
      if database.nil?
        if @config[:url] =~ /\/([^\/]*)$/
          database = $1
        else
          raise "Could not figure out what database this url is for #{@config["url"]}"
        end
      end

      ENV['PGHOST']     = @config[:host] if @config[:host]
      ENV['PGPORT']     = @config[:port].to_s if @config[:port]
      ENV['PGPASSWORD'] = @config[:password].to_s if @config[:password]
      search_path = "--schema=#{@config[:schema_search_path]}" if @config[:schema_search_path]

      @connection.connection.close
      begin
        definition = `pg_dump -i -U "#{@config[:username]}" -s -x -O #{search_path} #{database}`
        raise "Error dumping database" if $?.exitstatus == 1

        # need to patch away any references to SQL_ASCII as it breaks the JDBC driver
        definition.gsub(/SQL_ASCII/, 'UNICODE')
      ensure
        reconnect!
      end
    end

    # Returns the current client message level.
    def client_min_messages
      select_value('SHOW client_min_messages', 'SCHEMA')
    end

    # Set the client message level.
    def client_min_messages=(level)
      execute("SET client_min_messages TO '#{level}'", 'SCHEMA')
    end

    # Gets the maximum number columns postgres has, default 32
    def multi_column_index_limit
      defined?(@multi_column_index_limit) && @multi_column_index_limit || 32
    end
    
    # Sets the maximum number columns postgres has, default 32
    def multi_column_index_limit=(limit)
      @multi_column_index_limit = limit
    end
    
    # SELECT DISTINCT clause for a given set of columns and a given ORDER BY clause.
    #
    # PostgreSQL requires the ORDER BY columns in the select list for distinct queries, and
    # requires that the ORDER BY include the distinct column.
    #
    #   distinct("posts.id", "posts.created_at desc")
    def distinct(columns, orders) #:nodoc:
      return "DISTINCT #{columns}" if orders.empty?

      # Construct a clean list of column names from the ORDER BY clause, removing
      # any ASC/DESC modifiers
      order_columns = orders.collect { |s| s.gsub(/\s+(ASC|DESC)\s*/i, '') }.
        reject(&:blank?)
      order_columns = order_columns.
        zip((0...order_columns.size).to_a).map { |s,i| "#{s} AS alias_#{i}" }

      "DISTINCT #{columns}, #{order_columns * ', '}"
    end

    # ORDER BY clause for the passed order option.
    #
    # PostgreSQL does not allow arbitrary ordering when using DISTINCT ON, so we work around this
    # by wrapping the sql as a sub-select and ordering in that query.
    def add_order_by_for_association_limiting!(sql, options)
      return sql if options[:order].blank?

      order = options[:order].split(',').collect { |s| s.strip }.reject(&:blank?)
      order.map! { |s| 'DESC' if s =~ /\bdesc$/i }
      order = order.zip((0...order.size).to_a).map { |s,i| "id_list.alias_#{i} #{s}" }.join(', ')

      sql.replace "SELECT * FROM (#{sql}) AS id_list ORDER BY #{order}"
    end

    def quote(value, column = nil) #:nodoc:
      return super unless column

      # TODO recent 4.0 (master) seems to be passing a ColumnDefinition here :
      #   NoMethodError: undefined method `sql_type' for #<ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::ColumnDefinition:0x634f6b>
      # .../activerecord-jdbc-adapter/lib/arjdbc/postgresql/adapter.rb:1014:in `quote'
      # .../gems/rails-817e8fad5a84/activerecord/lib/active_record/connection_adapters/abstract/schema_statements.rb:698:in `add_column_options!'
      # .../activerecord-jdbc-adapter/lib/arjdbc/postgresql/adapter.rb:507:in `add_column_options!'
      # .../gems/rails-817e8fad5a84/activerecord/lib/active_record/connection_adapters/abstract_adapter.rb:168:in `add_column_options!'
      # .../gems/rails-817e8fad5a84/activerecord/lib/active_record/connection_adapters/abstract_adapter.rb:135:in `visit_ColumnDefinition'
      sql_type = column.sql_type rescue nil
      
      case value
      when Float
        if value.infinite? && column.type == :datetime
          "'#{value.to_s.downcase}'"
        elsif value.infinite? || value.nan?
          "'#{value.to_s}'"
        else
          super
        end
      when Numeric
        return super unless sql_type == 'money'
        # Not truly string input, so doesn't require (or allow) escape string syntax.
        ( column.type == :string || column.type == :text ) ? "'#{value}'" : super
      when String
        case sql_type
        when 'bytea' then "E'#{escape_bytea(value)}'::bytea" # "'#{escape_bytea(value)}'"
        when 'xml'   then "xml '#{quote_string(value)}'"
        when /^bit/
          case value
          # NOTE: as reported with #60 this is not quite "right" :
          #  "0103" will be treated as hexadecimal string
          #  "0102" will be treated as hexadecimal string
          #  "0101" will be treated as binary string
          #  "0100" will be treated as binary string
          # ... but is kept due Rails compatibility
          when /^[01]*$/      then "B'#{value}'" # Bit-string notation
          when /^[0-9A-F]*$/i then "X'#{value}'" # Hexadecimal notation
          end
        else
          super
        end
      when Array
        if column.array && AR4_COMPAT
          column_class = ::ActiveRecord::ConnectionAdapters::PostgreSQLColumn
          "'#{column_class.array_to_string(value, column, self)}'"
        else
          super
        end
      when Hash
        if sql_type == 'hstore' && AR4_COMPAT
          column_class = ::ActiveRecord::ConnectionAdapters::PostgreSQLColumn
          super(column_class.hstore_to_string(value), column)
        elsif sql_type == 'json' && AR4_COMPAT
          column_class = ::ActiveRecord::ConnectionAdapters::PostgreSQLColumn
          super(column_class.json_to_string(value), column)
        else super
        end
      when Range
        if /range$/ =~ sql_type && AR4_COMPAT
          column_class = ::ActiveRecord::ConnectionAdapters::PostgreSQLColumn
          "'#{column_class.range_to_string(value)}'::#{sql_type}"
        else
          super
        end
      when IPAddr
        if (sql_type == 'inet' || sql_type == 'cidr') && AR4_COMPAT
          column_class = ::ActiveRecord::ConnectionAdapters::PostgreSQLColumn
          super(column_class.cidr_to_string(value), column)
        else super
        end
      else
        super
      end
    end

    # Quotes a string, escaping any ' (single quote) and \ (backslash)
    # characters.
    def quote_string(string)
      quoted = string.gsub("'", "''")
      unless standard_conforming_strings?
        quoted.gsub!(/\\/, '\&\&')
      end
      quoted
    end

    def escape_bytea(string)
      if string
        if supports_hex_escaped_bytea?
          "\\\\x#{string.unpack("H*")[0]}"
        else
          result = ''
          string.each_byte { |c| result << sprintf('\\\\%03o', c) }
          result
        end
      end
    end
    
    def quote_table_name(name)
      schema, name_part = extract_pg_identifier_from_name(name.to_s)
        
      unless name_part
        quote_column_name(schema)
      else
        table_name, name_part = extract_pg_identifier_from_name(name_part)
        "#{quote_column_name(schema)}.#{quote_column_name(table_name)}"
      end
    end

    def quote_table_name_for_assignment(table, attr)
      quote_column_name(attr)
    end

    def quote_column_name(name)
      %("#{name.to_s.gsub("\"", "\"\"")}")
    end
    
    # Quote date/time values for use in SQL input. 
    # Includes microseconds if the value is a Time responding to usec.
    def quoted_date(value) #:nodoc:
      result = super
      if value.acts_like?(:time) && value.respond_to?(:usec)
        "#{result}.#{sprintf("%06d", value.usec)}"
      end
      result = "#{result.sub(/^-/, '')} BC" if value.year < 0
      result
    end
    
    def supports_disable_referential_integrity? # :nodoc:
      true
    end

    def disable_referential_integrity # :nodoc:
      if supports_disable_referential_integrity?
        begin
          execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER ALL" }.join(";"))
        rescue
          execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER USER" }.join(";"))
        end
      end
      yield
    ensure
      if supports_disable_referential_integrity?
        begin
          execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} ENABLE TRIGGER ALL" }.join(";"))
        rescue
          execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} ENABLE TRIGGER USER" }.join(";"))
        end
      end
    end

    def rename_table(table_name, new_name)
      execute "ALTER TABLE #{quote_table_name(table_name)} RENAME TO #{quote_table_name(new_name)}"
      pk, seq = pk_and_sequence_for(new_name)
      if seq == "#{table_name}_#{pk}_seq"
        new_seq = "#{new_name}_#{pk}_seq"
        execute "ALTER TABLE #{quote_table_name(seq)} RENAME TO #{quote_table_name(new_seq)}"
      end
      rename_table_indexes(table_name, new_name) if respond_to?(:rename_table_indexes) # AR-4.0 SchemaStatements
    end
    
    # Adds a new column to the named table.
    # See TableDefinition#column for details of the options you can use.
    def add_column(table_name, column_name, type, options = {})
      default = options[:default]
      notnull = options[:null] == false

      # Add the column.
      execute("ALTER TABLE #{quote_table_name(table_name)} ADD COLUMN #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}")

      change_column_default(table_name, column_name, default) if options_include_default?(options)
      change_column_null(table_name, column_name, false, default) if notnull
    end

    # Changes the column of a table.
    def change_column(table_name, column_name, type, options = {})
      quoted_table_name = quote_table_name(table_name)

      begin
        execute "ALTER TABLE #{quoted_table_name} ALTER COLUMN #{quote_column_name(column_name)} TYPE #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
      rescue ActiveRecord::StatementInvalid => e
        raise e if postgresql_version > 80000
        # This is PostgreSQL 7.x, so we have to use a more arcane way of doing it.
        begin
          begin_db_transaction
          tmp_column_name = "#{column_name}_ar_tmp"
          add_column(table_name, tmp_column_name, type, options)
          execute "UPDATE #{quoted_table_name} SET #{quote_column_name(tmp_column_name)} = CAST(#{quote_column_name(column_name)} AS #{type_to_sql(type, options[:limit], options[:precision], options[:scale])})"
          remove_column(table_name, column_name)
          rename_column(table_name, tmp_column_name, column_name)
          commit_db_transaction
        rescue
          rollback_db_transaction
        end
      end

      change_column_default(table_name, column_name, options[:default]) if options_include_default?(options)
      change_column_null(table_name, column_name, options[:null], options[:default]) if options.key?(:null)
    end

    # Changes the default value of a table column.
    def change_column_default(table_name, column_name, default)
      execute "ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} SET DEFAULT #{quote(default)}"
    end

    def change_column_null(table_name, column_name, null, default = nil)
      unless null || default.nil?
        execute("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
      end
      execute("ALTER TABLE #{quote_table_name(table_name)} ALTER #{quote_column_name(column_name)} #{null ? 'DROP' : 'SET'} NOT NULL")
    end

    def rename_column(table_name, column_name, new_column_name) # :nodoc:
      execute "ALTER TABLE #{quote_table_name(table_name)} RENAME COLUMN #{quote_column_name(column_name)} TO #{quote_column_name(new_column_name)}"
      rename_column_indexes(table_name, column_name, new_column_name) if respond_to?(:rename_column_indexes) # AR-4.0 SchemaStatements
    end

    def remove_index!(table_name, index_name) #:nodoc:
      execute "DROP INDEX #{quote_table_name(index_name)}"
    end

    def index_name_length
      63
    end

    # Returns the list of all column definitions for a table.
    def columns(table_name, name = nil)
      klass = ::ActiveRecord::ConnectionAdapters::PostgreSQLColumn
      column_definitions(table_name).map do |row|
        # name, type, default, notnull, oid, fmod
        name = row[0]; type = row[1]; default = row[2]
        notnull = row[3]; oid = row[4]; fmod = row[5]
        # oid = OID::TYPE_MAP.fetch(oid.to_i, fmod.to_i) { OID::Identity.new }
        notnull = notnull == 't' if notnull.is_a?(String) # JDBC gets true/false
        # for ID columns we get a bit of non-sense default :
        # e.g. "nextval('mixed_cases_id_seq'::regclass"
        default = nil if default =~ /^nextval\(.*?\:\:regclass\)$/
        klass.new(name, default, oid, type, ! notnull)
      end
    end
    
    # Returns the list of a table's column names, data types, and default values.
    #
    # If the table name is not prefixed with a schema, the database will
    # take the first match from the schema search path.
    #
    # Query implementation notes:
    #  - format_type includes the column size constraint, e.g. varchar(50)
    #  - ::regclass is a function that gives the id for a table name
    def column_definitions(table_name) #:nodoc:
      select_rows(<<-end_sql, 'SCHEMA')
        SELECT a.attname, format_type(a.atttypid, a.atttypmod),
               pg_get_expr(d.adbin, d.adrelid), a.attnotnull, a.atttypid, a.atttypmod
          FROM pg_attribute a LEFT JOIN pg_attrdef d
            ON a.attrelid = d.adrelid AND a.attnum = d.adnum
         WHERE a.attrelid = '#{quote_table_name(table_name)}'::regclass
           AND a.attnum > 0 AND NOT a.attisdropped
         ORDER BY a.attnum
      end_sql
    end
    private :column_definitions
    
    def tables(name = nil)
      select_values(<<-SQL, 'SCHEMA')
        SELECT tablename
        FROM pg_tables
        WHERE schemaname = ANY (current_schemas(false))
      SQL
    end

    def table_exists?(name)
      schema, table = extract_schema_and_table(name.to_s)
      return false unless table # abstract classes - nil table name

      binds = [[ nil, table.gsub(/(^"|"$)/,'') ]]
      binds << [ nil, schema ] if schema
      
      exec_query_raw(<<-SQL, 'SCHEMA', binds).first["table_count"] > 0
        SELECT COUNT(*) as table_count
        FROM pg_tables
        WHERE tablename = ?
        AND schemaname = #{schema ? "?" : "ANY (current_schemas(false))"}
      SQL
    end
    
    IndexDefinition = ::ActiveRecord::ConnectionAdapters::IndexDefinition # :nodoc:
    if ActiveRecord::VERSION::MAJOR < 3 || 
        ( ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR <= 1 )
      # NOTE: make sure we accept 6 arguments (>= 3.2) as well as 5 (<= 3.1) :
      # allow 6 on 3.1 : Struct.new(:table, :name, :unique, :columns, :lengths)
      IndexDefinition.class_eval do
        def initialize(table, name, unique = nil, columns = nil, lengths = nil, orders = nil)
          super(table, name, unique, columns, lengths) # @see {#indexes}
        end
      end
    end
    
    # Returns an array of indexes for the given table.
    def indexes(table_name, name = nil)
      # NOTE: maybe it's better to leave things of to the JDBC API ?!
      result = select_rows(<<-SQL, 'SCHEMA')
        SELECT distinct i.relname, d.indisunique, d.indkey, pg_get_indexdef(d.indexrelid), t.oid
        FROM pg_class t
        INNER JOIN pg_index d ON t.oid = d.indrelid
        INNER JOIN pg_class i ON d.indexrelid = i.oid
        WHERE i.relkind = 'i'
        AND d.indisprimary = 'f'
        AND t.relname = '#{table_name}'
        AND i.relnamespace IN (SELECT oid FROM pg_namespace WHERE nspname = ANY (current_schemas(false)) )
        ORDER BY i.relname
      SQL
      
      result.map! do |row|
        index_name = row[0]
        unique = row[1].is_a?(String) ? row[1] == 't' : row[1] # JDBC gets us a boolean
        indkey = row[2].is_a?(Java::OrgPostgresqlUtil::PGobject) ? row[2].value : row[2]
        indkey = indkey.split(" ")
        inddef = row[3]
        oid = row[4]

        columns = select_rows(<<-SQL, "SCHEMA")
          SELECT a.attnum, a.attname
          FROM pg_attribute a
          WHERE a.attrelid = #{oid}
          AND a.attnum IN (#{indkey.join(",")})
        SQL
        
        columns = Hash[ columns.each { |column| column[0] = column[0].to_s } ]
        column_names = columns.values_at(*indkey).compact

        # add info on sort order for columns (only desc order is explicitly specified, asc is the default)
        desc_order_columns = inddef.scan(/(\w+) DESC/).flatten
        orders = desc_order_columns.any? ? Hash[ desc_order_columns.map { |column| [column, :desc] } ] : {}
        
        column_names.empty? ? nil : IndexDefinition.new(table_name, index_name, unique, column_names, [], orders)
      end
      result.compact!
      result
    end

    # #override due RETURNING clause - can't do an {#execute_insert}
    def exec_insert(sql, name, binds, pk = nil, sequence_name = nil) # :nodoc:
      execute(sql, name, binds)
    end
    
    private
    
    def translate_exception(exception, message)
      case exception.message
      when /duplicate key value violates unique constraint/
        ::ActiveRecord::RecordNotUnique.new(message, exception)
      when /violates foreign key constraint/
        ::ActiveRecord::InvalidForeignKey.new(message, exception)
      else
        super
      end
    end
    
    # Extracts the table and schema name from +name+
    def extract_schema_and_table(name)
      schema, table = name.split('.', 2)

      unless table # A table was provided without a schema
        table  = schema
        schema = nil
      end

      if name =~ /^"/ # Handle quoted table names
        table  = name
        schema = nil
      end
      [schema, table]
    end

    def extract_pg_identifier_from_name(name)
      match_data = name[0, 1] == '"' ? name.match(/\"([^\"]+)\"/) : name.match(/([^\.]+)/)

      if match_data
        rest = name[match_data[0].length..-1]
        rest = rest[1..-1] if rest[0, 1] == "."
        [match_data[1], (rest.length > 0 ? rest : nil)]
      end
    end

    # taken from rails postgresql_adapter.rb
    def extract_table_ref_from_insert_sql(sql) # :nodoc:
      sql[/into\s+([^\(]*).*values\s*\(/i]
      $1.strip if $1
      # sql.split(" ", 4)[2].gsub('"', '')
    end
    
  end
end

module ActiveRecord::ConnectionAdapters
  
  PostgreSQLJdbcConnection.class_eval do
    
    # alias :java_native_database_types :set_native_database_types
    
    # @override to prevent connection from loading hash from JDBC meta-data, 
    # which can be expensive. We can do this since {#native_database_types} is 
    # defined in the adapter to use a hash not relying on driver's meta-data
    def set_native_database_types; @native_types = {}; end
    
  end
  
  remove_const(:PostgreSQLColumn) if const_defined?(:PostgreSQLColumn)

  class PostgreSQLColumn < JdbcColumn
    include ArJdbc::PostgreSQL::Column
    
    def initialize(name, default, oid_type, sql_type = nil, null = true)
      @oid_type = oid_type
      if sql_type =~ /\[\]$/
        @array = true
        super(name, default, sql_type[0..sql_type.length - 3], null)
      else
        @array = false
        super(name, default, sql_type, null)
      end
    end
        
  end

  remove_const(:PostgreSQLAdapter) if const_defined?(:PostgreSQLAdapter)
  
  class PostgreSQLAdapter < JdbcAdapter
    include ArJdbc::PostgreSQL
    include ArJdbc::PostgreSQL::ExplainSupport
    
    def initialize(*args)
      super
      
      # @local_tz is initialized as nil to avoid warnings when connect tries to use it
      @local_tz = nil
      @table_alias_length = nil
      
      configure_connection

      @local_tz = execute('SHOW TIME ZONE', 'SCHEMA').first["TimeZone"]
      @use_insert_returning = config.key?(:insert_returning) ? 
        self.class.type_cast_config_to_boolean(config[:insert_returning]) : nil
    end

    class ColumnDefinition < ActiveRecord::ConnectionAdapters::ColumnDefinition
      attr_accessor :array
    end

    module ColumnMethods
      def xml(*args)
        options = args.extract_options!
        column(args[0], 'xml', options)
      end

      def tsvector(*args)
        options = args.extract_options!
        column(args[0], 'tsvector', options)
      end

      def int4range(name, options = {})
        column(name, 'int4range', options)
      end

      def int8range(name, options = {})
        column(name, 'int8range', options)
      end

      def tsrange(name, options = {})
        column(name, 'tsrange', options)
      end

      def tstzrange(name, options = {})
        column(name, 'tstzrange', options)
      end

      def numrange(name, options = {})
        column(name, 'numrange', options)
      end

      def daterange(name, options = {})
        column(name, 'daterange', options)
      end

      def hstore(name, options = {})
        column(name, 'hstore', options)
      end

      def ltree(name, options = {})
        column(name, 'ltree', options)
      end

      def inet(name, options = {})
        column(name, 'inet', options)
      end

      def cidr(name, options = {})
        column(name, 'cidr', options)
      end

      def macaddr(name, options = {})
        column(name, 'macaddr', options)
      end

      def uuid(name, options = {})
        column(name, 'uuid', options)
      end

      def json(name, options = {})
        column(name, 'json', options)
      end
    end

    class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
      include ColumnMethods
      
      def primary_key(name, type = :primary_key, options = {})
        return super unless type == :uuid
        options[:default] ||= 'uuid_generate_v4()'
        options[:primary_key] = true
        column name, type, options
      end if ActiveRecord::VERSION::MAJOR > 3 # 3.2 super expects (name)
      
      def column(name, type = nil, options = {})
        super
        column = self[name]
        # NOTE: <= 3.1 no #new_column_definition hard-coded ColumnDef.new :
        # column = self[name] || ColumnDefinition.new(@base, name, type)
        # thus we simply do not support array column definitions on <= 3.1
        if column.is_a?(ColumnDefinition)
          column.array = options[:array]
        end
        self
      end

      private

      if ActiveRecord::VERSION::MAJOR > 3
        
        def create_column_definition(name, type)
          ColumnDefinition.new name, type
        end
        
      else # no #create_column_definition on 3.2
        
        def new_column_definition(base, name, type)
          definition = ColumnDefinition.new base, name, type
          @columns << definition
          @columns_hash[name] = definition
          definition
        end
        
      end
      
    end

    def table_definition(*args)
      new_table_definition(TableDefinition, *args)
    end
    
    class Table < ActiveRecord::ConnectionAdapters::Table
      include ColumnMethods
    end

    def update_table_definition(table_name, base)
      Table.new(table_name, base)
    end if ActiveRecord::VERSION::MAJOR > 3
    
    def jdbc_connection_class(spec)
      ::ArJdbc::PostgreSQL.jdbc_connection_class
    end

    def jdbc_column_class
      ::ActiveRecord::ConnectionAdapters::PostgreSQLColumn
    end
    
    # some QUOTING caching :
    
    @@quoted_table_names = {}
    
    def quote_table_name(name)
      unless quoted = @@quoted_table_names[name]
        quoted = super
        @@quoted_table_names[name] = quoted.freeze
      end
      quoted
    end
    
    @@quoted_column_names = {}
    
    def quote_column_name(name)
      unless quoted = @@quoted_column_names[name]
        quoted = super
        @@quoted_column_names[name] = quoted.freeze
      end
      quoted
    end
    
  end
end

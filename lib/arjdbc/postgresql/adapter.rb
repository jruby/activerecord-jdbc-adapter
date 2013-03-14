require 'arjdbc/postgresql/explain_support'

module ArJdbc
  module PostgreSQL
    def self.extended(adapter)
      (class << adapter; self; end).class_eval do
        alias_chained_method :columns, :query_cache, :pg_columns
      end
      
      adapter.configure_connection
    end

    def self.column_selector
      [/postgre/i, lambda {|cfg,col| col.extend(::ArJdbc::PostgreSQL::Column)}]
    end

    def self.jdbc_connection_class
      ::ActiveRecord::ConnectionAdapters::PostgresJdbcConnection
    end
    
    # Configures the encoding, verbosity, schema search path, and time zone of the connection.
    # This is called by #connect and should not be called manually.
    def configure_connection
      if encoding = config[:encoding]
        self.set_client_encoding(encoding)
      end
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

    # column behavior based on postgresql_adapter in rails project
    # https://github.com/rails/rails/blob/3-1-stable/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb#L41
    module Column
      def self.included(base)
        class << base
          attr_accessor :money_precision
          def string_to_time(string)
            return string unless String === string

            case string
            when 'infinity' then 1.0 / 0.0
            when '-infinity' then -1.0 / 0.0
            else
              super
            end
          end
        end
      end

      private
      # Extracts the value from a Postgresql column default definition
      def default_value(default)
        case default
          # This is a performance optimization for Ruby 1.9.2 in development.
          # If the value is nil, we return nil straight away without checking
          # the regular expressions. If we check each regular expression,
          # Regexp#=== will call NilClass#to_str, which will trigger
          # method_missing (defined by whiny nil in ActiveSupport) which
          # makes this method very very slow.
        when NilClass
          nil
          # Numeric types
        when /\A\(?(-?\d+(\.\d*)?\)?)\z/
          $1
          # Character types
        when /\A'(.*)'::(?:character varying|bpchar|text)\z/m
          $1
          # Character types (8.1 formatting)
        when /\AE'(.*)'::(?:character varying|bpchar|text)\z/m
          $1.gsub(/\\(\d\d\d)/) { $1.oct.chr }
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
          # Object identifier types
        when /\A-?\d+\z/
          $1
        else
          # Anything else is blank, some user type, or some function
          # and we can't know the value of that, so return nil.
          nil
        end
      end

      def extract_limit(sql_type)
        case sql_type
        when /^bigint/i then 8
        when /^smallint/i then 2
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
    end

    # constants taken from postgresql_adapter in rails project
    ADAPTER_NAME = 'PostgreSQL'

    def adapter_name #:nodoc:
      ADAPTER_NAME
    end

    def self.arel2_visitors(config)
      {
        'postgresql' => ::Arel::Visitors::PostgreSQL,
        'jdbcpostgresql' => ::Arel::Visitors::PostgreSQL,
        'pg' => ::Arel::Visitors::PostgreSQL
      }
    end

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

    NATIVE_DATABASE_TYPES = {
      :primary_key => "serial primary key",
      :string      => { :name => "character varying", :limit => 255 },
      :text        => { :name => "text" },
      :integer     => { :name => "integer" },
      :float       => { :name => "float" },
      :decimal     => { :name => "decimal" },
      :datetime    => { :name => "timestamp" },
      :timestamp   => { :name => "timestamp" },
      :time        => { :name => "time" },
      :date        => { :name => "date" },
      :binary      => { :name => "bytea" },
      :boolean     => { :name => "boolean" },
      :xml         => { :name => "xml" },
      :tsvector    => { :name => "tsvector" }
    }
    
    def native_database_types
      NATIVE_DATABASE_TYPES
    end
    
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

    def supports_index_sort_order? # :nodoc:
      true
    end
    
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

    # Returns the configured supported identifier length supported by PostgreSQL,
    # or report the default of 63 on PostgreSQL 7.x.
    def table_alias_length
      @table_alias_length ||= (postgresql_version >= 80000 ? select_one('SHOW max_identifier_length')['max_identifier_length'].to_i : 63)
    end

    def default_sequence_name(table_name, pk = nil)
      default_pk, default_seq = pk_and_sequence_for(table_name)
      default_seq || "#{table_name}_#{pk || default_pk || 'id'}_seq"
    end

    # Resets sequence to the max value of the table's pk if present.
    def reset_pk_sequence!(table, pk = nil, sequence = nil) #:nodoc:
      unless pk and sequence
        default_pk, default_sequence = pk_and_sequence_for(table)
        pk ||= default_pk
        sequence ||= default_sequence
      end
      if pk
        if sequence
          quoted_sequence = quote_column_name(sequence)

          select_value <<-end_sql, 'Reset sequence'
              SELECT setval('#{quoted_sequence}', (SELECT COALESCE(MAX(#{quote_column_name pk})+(SELECT increment_by FROM #{quoted_sequence}), (SELECT min_value FROM #{quoted_sequence})) FROM #{quote_table_name(table)}), false)
            end_sql
        else
          @logger.warn "#{table} has primary key #{pk} with no default sequence" if @logger
        end
      end
    end

    # Find a table's primary key and sequence.
    def pk_and_sequence_for(table) #:nodoc:
      # First try looking for a sequence with a dependency on the
      # given table's primary key.
      result = select(<<-end_sql, 'PK and serial sequence')[0]
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

      if result.nil? or result.empty?
        # If that fails, try parsing the primary key's default value.
        # Support the 7.x and 8.0 nextval('foo'::text) as well as
        # the 8.1+ nextval('foo'::regclass).
        result = select(<<-end_sql, 'PK and custom sequence')[0]
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

      [result["attname"], result["relname"]]
    rescue
      nil
    end

    # Insert logic for pre-AR-3.1 adapters
    def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [])
      # Extract the table from the insert sql. Yuck.
      table = sql.split(" ", 4)[2].gsub('"', '')

      # Try an insert with 'returning id' if available (PG >= 8.2)
      if supports_insert_with_returning? && id_value.nil?
        pk, sequence_name = *pk_and_sequence_for(table) unless pk
        if pk
          sql = to_sql(sql, binds)
          return select_value("#{sql} RETURNING #{quote_column_name(pk)}")
        end
      end

      # Otherwise, plain insert
      execute(sql, name, binds)

      # Don't need to look up id_value if we already have it.
      # (and can't in case of non-sequence PK)
      unless id_value
        # If neither pk nor sequence name is given, look them up.
        unless pk || sequence_name
          pk, sequence_name = *pk_and_sequence_for(table)
        end

        # If a pk is given, fallback to default sequence name.
        # Don't fetch last insert id for a table without a pk.
        if pk && sequence_name ||= default_sequence_name(table, pk)
          id_value = last_insert_id(table, sequence_name)
        end
      end
      id_value
    end
    
    # taken from rails postgresql_adapter.rb
    def sql_for_insert(sql, pk, id_value, sequence_name, binds)
      unless pk
        table_ref = extract_table_ref_from_insert_sql(sql)
        pk = primary_key(table_ref) if table_ref
      end

      sql = "#{sql} RETURNING #{quote_column_name(pk)}" if pk

      [sql, binds]
    end
    
    def primary_key(table)
      pk_and_sequence = pk_and_sequence_for(table)
      pk_and_sequence && pk_and_sequence.first
    end

    def pg_columns(table_name, name=nil)
      column_definitions(table_name).map do |row|
        ::ActiveRecord::ConnectionAdapters::PostgreSQLColumn.new(
          row["column_name"], row["column_default"], row["column_type"],
          row["column_not_null"] == "f")
      end
    end

    # current database name
    def current_database
      exec_query("select current_database() as database").
        first["database"]
    end

    # current database encoding
    def encoding
      exec_query(<<-end_sql).first["encoding"]
        SELECT pg_encoding_to_char(pg_database.encoding) as encoding
        FROM pg_database
        WHERE pg_database.datname LIKE '#{current_database}'
      end_sql
    end

    # Sets the maximum number columns postgres has, default 32
    def multi_column_index_limit=(limit)
      @multi_column_index_limit = limit
    end

    # Gets the maximum number columns postgres has, default 32
    def multi_column_index_limit
      defined?(@multi_column_index_limit) && @multi_column_index_limit || 32
    end

    # Based on postgresql_adapter.rb
    def indexes(table_name, name = nil)
      schemas = schema_search_path.split(/,/).map { |p| quote(p) }.join(',')
      result = select_rows(<<-SQL, name)
        SELECT i.relname, d.indisunique, a.attname, a.attnum, d.indkey
          FROM pg_class t, pg_class i, pg_index d, pg_attribute a,
          generate_series(0,#{multi_column_index_limit - 1}) AS s(i)
         WHERE i.relkind = 'i'
           AND d.indexrelid = i.oid
           AND d.indisprimary = 'f'
           AND t.oid = d.indrelid
           AND t.relname = '#{table_name}'
           AND i.relnamespace IN (SELECT oid FROM pg_namespace WHERE nspname = ANY (current_schemas(false)) )
           AND a.attrelid = t.oid
           AND d.indkey[s.i]=a.attnum
        ORDER BY i.relname
      SQL

      current_index = nil
      indexes = []

      insertion_order = []
      index_order = nil

      result.each do |row|
        if current_index != row[0]

          (index_order = row[4].split(' ')).each_with_index{ |v, i| index_order[i] = v.to_i }
          indexes << ::ActiveRecord::ConnectionAdapters::IndexDefinition.new(table_name, row[0], row[1] == "t", [])
          current_index = row[0]
        end
        insertion_order = row[3]
        ind = index_order.index(insertion_order)
        indexes.last.columns[ind] = row[2]
      end

      indexes
    end

    # take id from result of insert query
    def last_inserted_id(result)
      if result.is_a? Fixnum
        result
      else
        result.first.first[1]
      end
    end

    def last_insert_id(table, sequence_name)
      Integer(select_value("SELECT currval('#{sequence_name}')"))
    end

    def recreate_database(name, options = {})
      drop_database(name)
      create_database(name, options)
    end

    def create_database(name, options = {})
      options = options.with_indifferent_access
      create_query = "CREATE DATABASE \"#{name}\" ENCODING='#{options[:encoding] || 'utf8'}'"
      create_query += options.symbolize_keys.sum('') do |key, value|
        case key
          when :owner
            " OWNER = \"#{value}\""
          when :template
            " TEMPLATE = \"#{value}\""
          when :tablespace
            " TABLESPACE = \"#{value}\""
          when :connection_limit
            " CONNECTION LIMIT = #{value}"
          else
            ""
        end
      end
      execute create_query
    end

    def drop_database(name)
      execute "DROP DATABASE IF EXISTS \"#{name}\""
    end

    def create_schema(schema_name, pg_username)
      execute("CREATE SCHEMA \"#{schema_name}\" AUTHORIZATION \"#{pg_username}\"")
    end

    def drop_schema(schema_name)
      execute("DROP SCHEMA \"#{schema_name}\"")
    end

    def all_schemas
      select('select nspname from pg_namespace').map {|r| r["nspname"] }
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

    # Returns the active schema search path.
    def schema_search_path
      @schema_search_path ||= exec_query('SHOW search_path', 'SCHEMA')[0]['search_path']
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

    # Returns the current schema name.
    def current_schema
      exec_query('SELECT current_schema', 'SCHEMA')[0]["current_schema"]
    end

    # Returns the current client message level.
    def client_min_messages
      exec_query('SHOW client_min_messages', 'SCHEMA')[0]['client_min_messages']
    end

    # Set the client message level.
    def client_min_messages=(level)
      execute("SET client_min_messages TO '#{level}'", 'SCHEMA')
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

    # from postgres_adapter.rb in rails project
    # https://github.com/rails/rails/blob/3-1-stable/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb#L412
    # Quotes PostgreSQL-specific data types for SQL input.
    def quote(value, column = nil) #:nodoc:
      return super unless column

      case value
      when Float
        return super unless value.infinite? && column.type == :datetime
        "'#{value.to_s.downcase}'"
      when Numeric
        return super unless column.sql_type == 'money'
        # Not truly string input, so doesn't require (or allow) escape string syntax.
        "'#{value}'"
      when String
        case column.sql_type
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
    
    def quote_column_name(name)
      %("#{name.to_s.gsub("\"", "\"\"")}")
    end
    
    def quoted_date(value) #:nodoc:
      if value.acts_like?(:time) && value.respond_to?(:usec)
        "#{super}.#{sprintf("%06d", value.usec)}"
      else
        super
      end
    end

    def disable_referential_integrity # :nodoc:
      execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER ALL" }.join(";"))
      yield
    ensure
      execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} ENABLE TRIGGER ALL" }.join(";"))
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

    def rename_column(table_name, column_name, new_column_name) #:nodoc:
      execute "ALTER TABLE #{quote_table_name(table_name)} RENAME COLUMN #{quote_column_name(column_name)} TO #{quote_column_name(new_column_name)}"
      rename_column_indexes(table_name, column_name, new_column_name) if respond_to?(:rename_column_indexes) # AR-4.0 SchemaStatements
    end

    def remove_index!(table_name, index_name) #:nodoc:
      execute "DROP INDEX #{quote_table_name(index_name)}"
    end

    def index_name_length
      63
    end

    # Maps logical Rails types to PostgreSQL-specific data types.
    def type_to_sql(type, limit = nil, precision = nil, scale = nil)
      case type.to_sym
      when :integer
        return 'integer' unless limit
        case limit.to_i
          when 1, 2; 'smallint'
          when 3, 4; 'integer'
          when 5..8; 'bigint'
          else raise(ActiveRecordError, "No integer type has byte size #{limit}. Use a numeric with precision 0 instead.")
        end
      when :binary
        super(type, nil, nil, nil)
      else
        super
      end
    end
    
    def tables(name = nil)
      exec_query(<<-SQL, 'SCHEMA').map { |row| row["tablename"] }
          SELECT tablename
          FROM pg_tables
          WHERE schemaname = ANY (current_schemas(false))
      SQL
    end

    def table_exists?(name)
      schema, table = extract_schema_and_table(name.to_s)
      return false unless table # Abstract classes is having nil table name

      binds = [[nil, table.gsub(/(^"|"$)/,'')]]
      binds << [nil, schema] if schema

      exec_query(<<-SQL, 'SCHEMA', binds).first["table_count"] > 0
          SELECT COUNT(*) as table_count
          FROM pg_tables
          WHERE tablename = ?
          AND schemaname = #{schema ? "?" : "ANY (current_schemas(false))"}
      SQL
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

    # Returns the list of a table's column names, data types, and default values.
    #
    # The underlying query is roughly:
    #  SELECT column.name, column.type, default.value
    #    FROM column LEFT JOIN default
    #      ON column.table_id = default.table_id
    #     AND column.num = default.column_num
    #   WHERE column.table_id = get_table_id('table_name')
    #     AND column.num > 0
    #     AND NOT column.is_dropped
    #   ORDER BY column.num
    #
    # If the table name is not prefixed with a schema, the database will
    # take the first match from the schema search path.
    #
    # Query implementation notes:
    #  - format_type includes the column size constraint, e.g. varchar(50)
    #  - ::regclass is a function that gives the id for a table name
    def column_definitions(table_name) #:nodoc:
      exec_query(<<-end_sql, 'SCHEMA')
            SELECT a.attname as column_name, format_type(a.atttypid, a.atttypmod) as column_type, d.adsrc as column_default, a.attnotnull as column_not_null
              FROM pg_attribute a LEFT JOIN pg_attrdef d
                ON a.attrelid = d.adrelid AND a.attnum = d.adnum
             WHERE a.attrelid = '#{quote_table_name(table_name)}'::regclass
               AND a.attnum > 0 AND NOT a.attisdropped
             ORDER BY a.attnum
          end_sql
    end

    def extract_pg_identifier_from_name(name)
      match_data = name[0,1] == '"' ? name.match(/\"([^\"]+)\"/) : name.match(/([^\.]+)/)

      if match_data
        rest = name[match_data[0].length..-1]
        rest = rest[1..-1] if rest[0,1] == "."
        [match_data[1], (rest.length > 0 ? rest : nil)]
      end
    end

    # taken from rails postgresql_adapter.rb
    def extract_table_ref_from_insert_sql(sql) # :nodoc:
      sql[/into\s+([^\(]*).*values\s*\(/i]
      $1.strip if $1
    end
    
  end
end

module ActiveRecord::ConnectionAdapters
  remove_const(:PostgreSQLAdapter) if const_defined?(:PostgreSQLAdapter)

  class PostgreSQLColumn < JdbcColumn
    include ArJdbc::PostgreSQL::Column

    def initialize(name, *args)
      if Hash === name
        super
      else
        super(nil, name, *args)
      end
    end

    def call_discovered_column_callbacks(*)
    end
  end

  class PostgresJdbcConnection < JdbcConnection
    alias :java_native_database_types :set_native_database_types

    # override to prevent connection from loading hash from jdbc
    # metadata, which can be expensive. We can do this since
    # native_database_types is defined in the adapter to use a static hash
    # not relying on the driver's metadata
    def set_native_database_types
      @native_types = {}
    end
  end

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
    end

    class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
      def xml(*args)
        options = args.extract_options!
        column(args[0], "xml", options)
      end

      def tsvector(*args)
        options = args.extract_options!
        column(args[0], "tsvector", options)
      end
    end

    def table_definition
      TableDefinition.new(self)
    end

    def jdbc_connection_class(spec)
      ::ArJdbc::PostgreSQL.jdbc_connection_class
    end

    def jdbc_column_class
      ActiveRecord::ConnectionAdapters::PostgreSQLColumn
    end

    alias_chained_method :columns, :query_cache, :pg_columns
    
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

# Don't need to load native postgres adapter
$LOADED_FEATURES << 'active_record/connection_adapters/postgresql_adapter.rb'
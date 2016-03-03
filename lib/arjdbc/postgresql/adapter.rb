# frozen_string_literal: false
ArJdbc.load_java_part :PostgreSQL

require 'ipaddr'

module ArJdbc
  # Strives to provide Rails built-in PostgreSQL adapter (API) compatibility.
  module PostgreSQL

    # @deprecated no longer used
    # @private
    AR4_COMPAT = AR40
    # @deprecated no longer used
    # @private
    AR42_COMPAT = AR42

    require 'arjdbc/postgresql/column'
    require 'arjdbc/postgresql/explain_support'
    require 'arjdbc/postgresql/schema_creation' # AR 4.x
    # @private
    IndexDefinition = ::ActiveRecord::ConnectionAdapters::IndexDefinition

    # @private
    ForeignKeyDefinition = ::ActiveRecord::ConnectionAdapters::ForeignKeyDefinition if ::ActiveRecord::ConnectionAdapters.const_defined? :ForeignKeyDefinition

    # @private
    Type = ::ActiveRecord::Type if AR42

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#jdbc_connection_class
    def self.jdbc_connection_class
      ::ActiveRecord::ConnectionAdapters::PostgreSQLJdbcConnection
    end

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#jdbc_column_class
    def jdbc_column_class; ::ActiveRecord::ConnectionAdapters::PostgreSQLColumn end

    # @private
    def init_connection(jdbc_connection)
      meta = jdbc_connection.meta_data
      if meta.driver_version.index('JDBC3') # e.g. 'PostgreSQL 9.2 JDBC4 (build 1002)'
        config[:connection_alive_sql] ||= 'SELECT 1'
      else
        # NOTE: since the loaded Java driver class can't change :
        PostgreSQL.send(:remove_method, :init_connection) rescue nil
      end
    end

    # @see ActiveRecord::ConnectionAdapters::Jdbc::ArelSupport
    def self.arel_visitor_type(config = nil)
      require 'arel/visitors/postgresql_jdbc'
      ::Arel::Visitors::PostgreSQL
    end

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#bind_substitution
    # @private
    class BindSubstitution < ::Arel::Visitors::PostgreSQL
      include ::Arel::Visitors::BindVisitor
    end if defined? ::Arel::Visitors::BindVisitor

    ADAPTER_NAME = 'PostgreSQL'.freeze

    def adapter_name
      ADAPTER_NAME
    end

    def postgresql_version
      @postgresql_version ||=
        begin
          version = select_version
          if version =~ /PostgreSQL (\d+)\.(\d+)\.(\d+)/
            ($1.to_i * 10000) + ($2.to_i * 100) + $3.to_i
          else
            0
          end
        end
    end

    def select_version
      @_version ||= select_value('SELECT version()')
    end
    private :select_version

    def redshift?
      # SELECT version() :
      #  PostgreSQL 8.0.2 on i686-pc-linux-gnu, compiled by GCC gcc (GCC) 3.4.2 20041017 (Red Hat 3.4.2-6.fc3), Redshift 1.0.647
      if ( redshift = config[:redshift] ).nil?
        redshift = !! (select_version || '').index('Redshift')
      end
      redshift
    end
    private :redshift?

    def use_insert_returning?
      if @use_insert_returning.nil?
        @use_insert_returning = supports_insert_with_returning?
      end
      @use_insert_returning
    end

    def set_client_encoding(encoding)
      ActiveRecord::Base.logger.warn "client_encoding is set by the driver and should not be altered, ('#{encoding}' ignored)"
      ActiveRecord::Base.logger.debug "Set the 'allowEncodingChanges' driver property (e.g. using config[:properties]) if you need to override the client encoding when doing a copy."
    end

    # Configures the encoding, verbosity, schema search path, and time zone of the connection.
    # This is called on `connection.connect` and should not be called manually.
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
      elsif tz = local_tz
        execute("SET time zone '#{tz}'", 'SCHEMA')
      end unless redshift?

      # SET statements from :variables config hash
      # http://www.postgresql.org/docs/8.3/static/sql-set.html
      (config[:variables] || {}).map do |k, v|
        if v == ':default' || v == :default
          # Sets the value to the global or compile default
          execute("SET SESSION #{k} TO DEFAULT", 'SCHEMA')
        elsif ! v.nil?
          execute("SET SESSION #{k} TO #{quote(v)}", 'SCHEMA')
        end
      end
    end

    # @private
    ActiveRecordError = ::ActiveRecord::ActiveRecordError

    # Maps logical Rails types to PostgreSQL-specific data types.
    def type_to_sql(type, limit = nil, precision = nil, scale = nil)
      case type.to_s
      when 'binary'
        # PostgreSQL doesn't support limits on binary (bytea) columns.
        # The hard limit is 1Gb, because of a 32-bit size field, and TOAST.
        case limit
        when nil, 0..0x3fffffff; super(type)
        else raise(ActiveRecordError, "No binary type has byte size #{limit}.")
        end
      when 'text'
        # PostgreSQL doesn't support limits on text columns.
        # The hard limit is 1Gb, according to section 8.3 in the manual.
        case limit
        when nil, 0..0x3fffffff; super(type)
        else raise(ActiveRecordError, "The limit on text can be at most 1GB - 1byte.")
        end
      when 'integer'
        return 'integer' unless limit

        case limit
          when 1, 2; 'smallint'
          when 3, 4; 'integer'
          when 5..8; 'bigint'
          else raise(ActiveRecordError, "No integer type has byte size #{limit}. Use a numeric with precision 0 instead.")
        end
      when 'datetime'
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
      return super(value, nil) unless column

      case value
      when String
        return super(value, column) unless 'bytea' == column.sql_type
        value # { :value => value, :format => 1 }
      when Array
        case column.sql_type
        when 'point'
          jdbc_column_class.point_to_string(value)
        when 'json', 'jsonb'
          jdbc_column_class.json_to_string(value)
        else
          return super(value, column) unless column.array?
          jdbc_column_class.array_to_string(value, column, self)
        end
      when NilClass
        if column.array? && array_member
          'NULL'
        elsif column.array?
          value
        else
          super(value, column)
        end
      when Hash
        case column.sql_type
        when 'hstore'
          jdbc_column_class.hstore_to_string(value, array_member)
        when 'json', 'jsonb'
          jdbc_column_class.json_to_string(value)
        else super(value, column)
        end
      when IPAddr
        return super unless column.sql_type == 'inet' || column.sql_type == 'cidr'
        jdbc_column_class.cidr_to_string(value)
      when Range
        return super(value, column) unless /range$/ =~ column.sql_type
        jdbc_column_class.range_to_string(value)
      else
        super(value, column)
      end
    end if AR40 && ! AR42

    # @private
    def _type_cast(value)
      case value
      when Type::Binary::Data
        # Return a bind param hash with format as binary.
        # See http://deveiate.org/code/pg/PGconn.html#method-i-exec_prepared-doc
        # for more information
        { :value => value.to_s, :format => 1 }
      when OID::Xml::Data, OID::Bit::Data
        value.to_s
      else
        super
      end
    end if AR42
    private :_type_cast if AR42

    NATIVE_DATABASE_TYPES = {
      :primary_key => "serial primary key",
      :string => { :name => "character varying", :limit => 255 },
      :text => { :name => "text" },
      :integer => { :name => "integer" },
      :float => { :name => "float" },
      :numeric => { :name => "numeric" },
      :decimal => { :name => "decimal" }, # :limit => 1000
      :datetime => { :name => "timestamp" },
      :timestamp => { :name => "timestamp" },
      :time => { :name => "time" },
      :date => { :name => "date" },
      :binary => { :name => "bytea" },
      :boolean => { :name => "boolean" },
      :xml => { :name => "xml" },
      # AR-JDBC added :
      #:timestamptz => { :name => "timestamptz" },
      #:timetz => { :name => "timetz" },
      :money => { :name=>"money" },
      :char => { :name => "char" },
      :serial => { :name => "serial" }, # auto-inc integer, bigserial, smallserial
    }

    NATIVE_DATABASE_TYPES.update({
      :tsvector => { :name => "tsvector" },
      :hstore => { :name => "hstore" },
      :inet => { :name => "inet" },
      :cidr => { :name => "cidr" },
      :macaddr => { :name => "macaddr" },
      :uuid => { :name => "uuid" },
      :json => { :name => "json" },
      :jsonb => { :name => "jsonb" },
      :ltree => { :name => "ltree" },
      # ranges :
      :daterange => { :name => "daterange" },
      :numrange => { :name => "numrange" },
      :tsrange => { :name => "tsrange" },
      :tstzrange => { :name => "tstzrange" },
      :int4range => { :name => "int4range" },
      :int8range => { :name => "int8range" },
    }) if AR40

    NATIVE_DATABASE_TYPES.update(
      :string => { :name => "character varying" },
      :bigserial => "bigserial",
      :bigint => { :name => "bigint" },
      :bit => { :name => "bit" },
      :bit_varying => { :name => "bit varying" }
    ) if AR42

    def native_database_types
      NATIVE_DATABASE_TYPES
    end

    # Adds `:array` option to the default set provided by the `AbstractAdapter`.
    # @override
    def prepare_column_options(column, types)
      spec = super
      spec[:array] = 'true' if column.respond_to?(:array) && column.array
      spec[:default] = "\"#{column.default_function}\"" if column.default_function
      spec
    end if AR40

    # Adds `:array` as a valid migration key.
    # @override
    def migration_keys
      super + [:array]
    end if AR40

    # Enable standard-conforming strings if available.
    def set_standard_conforming_strings
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

    def standard_conforming_strings?
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
    def supports_migrations?
      true
    end

    # Does PostgreSQL support finding primary key on non-Active Record tables?
    def supports_primary_key?
      true
    end

    # Does PostgreSQL support standard conforming strings?
    def supports_standard_conforming_strings?
      standard_conforming_strings?
      @standard_conforming_strings != :unsupported
    end

    def supports_hex_escaped_bytea?
      postgresql_version >= 90000
    end

    def supports_insert_with_returning?
      postgresql_version >= 80200
    end

    def supports_ddl_transactions?; true end

    def supports_transaction_isolation?; true end

    def supports_index_sort_order?; true end

    def supports_partial_index?; true end if AR40

    # Range data-types weren't introduced until PostgreSQL 9.2.
    def supports_ranges?
      postgresql_version >= 90200
    end if AR40

    def supports_transaction_isolation?(level = nil)
      true
    end

    # @override
    def supports_views?; true end

    # NOTE: handled by JdbcAdapter we override only to have save-point in logs :

    # @override
    def supports_savepoints?; true end

    # @override
    def create_savepoint(name = current_savepoint_name(true))
      log("SAVEPOINT #{name}", 'Savepoint') { super }
    end

    # @override
    def rollback_to_savepoint(name = current_savepoint_name(true))
      log("ROLLBACK TO SAVEPOINT #{name}", 'Savepoint') { super }
    end

    # @override
    def release_savepoint(name = current_savepoint_name(false))
      log("RELEASE SAVEPOINT #{name}", 'Savepoint') { super }
    end

    def supports_extensions?
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
        available = rows.first.first # true/false or 't'/'f'
        available == true || available == 't'
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

    def index_algorithms
      { :concurrently => 'CONCURRENTLY' }
    end

    # Set the authorized user for this session.
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

    # Resets sequence to the max value of the table's primary key if present.
    def reset_pk_sequence!(table, pk = nil, sequence = nil)
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
    def pk_and_sequence_for(table)
      # try looking for a seq with a dependency on the table's primary key :
      result = select(<<-end_sql, 'PK and Serial Sequence')[0]
          SELECT attr.attname, seq.relname
          FROM pg_class      seq,
               pg_attribute  attr,
               pg_depend     dep,
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
        # if that fails, try parsing the primary key's default value :
        result = select(<<-end_sql, 'PK and Custom Sequence')[0]
            SELECT attr.attname,
              CASE
                WHEN pg_get_expr(def.adbin, def.adrelid) !~* 'nextval' THEN NULL
                WHEN split_part(pg_get_expr(def.adbin, def.adrelid), '''', 2) ~ '.' THEN
                  substr(split_part(pg_get_expr(def.adbin, def.adrelid), '''', 2),
                    strpos(split_part(pg_get_expr(def.adbin, def.adrelid), '''', 2), '.')+1)
                ELSE split_part(pg_get_expr(def.adbin, def.adrelid), '''', 2)
              END as relname
            FROM pg_class       t
            JOIN pg_attribute   attr ON (t.oid = attrelid)
            JOIN pg_attrdef     def  ON (adrelid = attrelid AND adnum = attnum)
            JOIN pg_constraint  cons ON (conrelid = adrelid AND adnum = conkey[1])
            WHERE t.oid = '#{quote_table_name(table)}'::regclass
              AND cons.contype = 'p'
              AND pg_get_expr(def.adbin, def.adrelid) ~* 'nextval|uuid_generate'
          end_sql
      end

      [ result['attname'], result['relname'] ]
    rescue
      nil
    end

    def primary_key(table)
      result = select(<<-end_sql, 'SCHEMA').first
        SELECT attr.attname
        FROM pg_attribute attr
        INNER JOIN pg_constraint cons ON attr.attrelid = cons.conrelid AND attr.attnum = any(cons.conkey)
        WHERE cons.contype = 'p' AND cons.conrelid = '#{quote_table_name(table)}'::regclass
      end_sql

      result && result['attname']
      # pk_and_sequence = pk_and_sequence_for(table)
      # pk_and_sequence && pk_and_sequence.first
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

    # @override
    def sql_for_insert(sql, pk, id_value, sequence_name, binds)
      unless pk
        # Extract the table from the insert sql. Yuck.
        table_ref = extract_table_ref_from_insert_sql(sql)
        pk = primary_key(table_ref) if table_ref
      end

      if pk && use_insert_returning?
        sql = "#{sql} RETURNING #{quote_column_name(pk)}"
      end

      [ sql, binds ]
    end

    # @override due RETURNING clause
    def exec_insert(sql, name, binds, pk = nil, sequence_name = nil)
      # NOTE: 3.2 does not pass the PK on #insert (passed only into #sql_for_insert) :
      #   sql, binds = sql_for_insert(to_sql(arel, binds), pk, id_value, sequence_name, binds)
      # 3.2 :
      #  value = exec_insert(sql, name, binds)
      # 4.x :
      #  value = exec_insert(sql, name, binds, pk, sequence_name)
      if use_insert_returning? && ( pk || (sql.is_a?(String) && sql =~ /RETURNING "?\S+"?$/) )
        exec_query(sql, name, binds) # due RETURNING clause returns a result set
      else
        result = super
        if pk
          unless sequence_name
            table_ref = extract_table_ref_from_insert_sql(sql)
            sequence_name = default_sequence_name(table_ref, pk)
            return result unless sequence_name
          end
          last_insert_id_result(sequence_name)
        else
          result
        end
      end
    end

    # @note Only for "better" AR 4.0 compatibility.
    # @private
    def query(sql, name = nil)
      log(sql, name) do
        result = []
        @connection.execute_query_raw(sql, nil) do |*values|
          result << values
        end
        result
      end
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

    # Take an id from the result of an INSERT query.
    # @return [Integer, NilClass]
    def last_inserted_id(result)
      return nil if result.nil?
      return result if result.is_a? Integer
      # <ActiveRecord::Result @hash_rows=nil, @columns=["id"], @rows=[[3]]>
      # but it will work with [{ 'id' => 1 }] Hash wrapped results as well
      result.first.first[1] # .first = { "id"=>1 } .first = [ "id", 1 ]
    end

    def last_insert_id(table, sequence_name = nil)
      sequence_name = table if sequence_name.nil? # AR-4.0 1 argument
      last_insert_id_result(sequence_name)
    end

    def last_insert_id_result(sequence_name)
      select_value("SELECT currval('#{sequence_name}')", 'SQL')
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

    # @deprecated no longer used - handled with (AR built-in) Rake tasks
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
      return nil if redshift? # not supported on Redshift
      select_value('SHOW client_min_messages', 'SCHEMA')
    end

    # Set the client message level.
    def client_min_messages=(level)
      # NOTE: for now simply ignore the writer (no warn on Redshift) so that
      # the AR copy-pasted PpstgreSQL parts stay the same as much as possible
      return nil if redshift? # not supported on Redshift
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

    # @override
    def distinct(columns, orders)
      "DISTINCT #{columns_for_distinct(columns, orders)}"
    end

    # PostgreSQL requires the ORDER BY columns in the select list for distinct
    # queries, and requires that the ORDER BY include the distinct column.
    # @override Since AR 4.0 (on 4.1 {#distinct} is gone and won't be called).
    def columns_for_distinct(columns, orders)
      if orders.is_a?(String)
        orders = orders.split(','); orders.each(&:strip!)
      end

      order_columns = orders.reject(&:blank?).map! do |column|
        column = column.is_a?(String) ? column.dup : column.to_sql # AREL node
        column.gsub!(/\s+(?:ASC|DESC)\s*/i, '') # remove any ASC/DESC modifiers
        column.gsub!(/\s*NULLS\s+(?:FIRST|LAST)?\s*/i, '')
        column
      end
      order_columns.reject!(&:empty?)
      i = -1; order_columns.map! { |column| "#{column} AS alias_#{i += 1}" }

      columns = [ columns ]; columns.flatten!
      columns.push( *order_columns ).join(', ')
    end

    # ORDER BY clause for the passed order option.
    #
    # PostgreSQL does not allow arbitrary ordering when using DISTINCT ON,
    # so we work around this by wrapping the SQL as a sub-select and ordering
    # in that query.
    def add_order_by_for_association_limiting!(sql, options)
      return sql if options[:order].blank?

      order = options[:order].split(',').collect { |s| s.strip }.reject(&:blank?)
      order.map! { |s| 'DESC' if s =~ /\bdesc$/i }
      order = order.zip((0...order.size).to_a).map { |s,i| "id_list.alias_#{i} #{s}" }.join(', ')

      sql.replace "SELECT * FROM (#{sql}) AS id_list ORDER BY #{order}"
    end

    # @return [String]
    # @override
    def quote(value, column = nil)
      return super unless column && column.type
      return value if sql_literal?(value)

      case value
      when Float
        if value.infinite? && ( column.type == :datetime || column.type == :timestamp )
          "'#{value.to_s.downcase}'"
        elsif value.infinite? || value.nan?
          "'#{value.to_s}'"
        else super
        end
      when Numeric
        if column.respond_to?(:sql_type) && column.sql_type == 'money'
          "'#{value}'"
        elsif column.type == :string || column.type == :text
          "'#{value}'"
        else super
        end
      when String
        return "E'#{escape_bytea(value)}'::bytea" if column.type == :binary
        return "xml '#{quote_string(value)}'" if column.type == :xml
        sql_type = column.respond_to?(:sql_type) && column.sql_type
        sql_type && sql_type[0, 3] == 'bit' ? quote_bit(value) : super
      when Array
        if AR40 && column.array? # will be always falsy in AR < 4.0
          "'#{jdbc_column_class.array_to_string(value, column, self).gsub(/'/, "''")}'"
        elsif column.type == :json # only in AR-4.0
          super(jdbc_column_class.json_to_string(value), column)
        elsif column.type == :jsonb # only in AR-4.0
          super(jdbc_column_class.json_to_string(value), column)
        elsif column.type == :point # only in AR-4.0
          super(jdbc_column_class.point_to_string(value), column)
        else super
        end
      when Hash
        if column.type == :hstore # only in AR-4.0
          super(jdbc_column_class.hstore_to_string(value), column)
        elsif column.type == :json # only in AR-4.0
          super(jdbc_column_class.json_to_string(value), column)
        elsif column.type == :jsonb # only in AR-4.0
          super(jdbc_column_class.json_to_string(value), column)
        else super
        end
      when Range
        sql_type = column.respond_to?(:sql_type) && column.sql_type
        if sql_type && sql_type[-5, 5] == 'range' && AR40
          escaped = quote_string(jdbc_column_class.range_to_string(value))
          "'#{escaped}'::#{sql_type}"
        else super
        end
      when IPAddr
        if column.type == :inet || column.type == :cidr # only in AR-4.0
          super(jdbc_column_class.cidr_to_string(value), column)
        else super
        end
      else
        super
      end
    end unless AR42

    # @private
    def _quote(value)
      case value
      when Type::Binary::Data
        "E'#{escape_bytea(value.to_s)}'"
      when OID::Xml::Data
        "xml '#{quote_string(value.to_s)}'"
      when OID::Bit::Data
        if value.binary?
          "B'#{value}'"
        elsif value.hex?
          "X'#{value}'"
        end
      when Float
        if value.infinite? || value.nan?
          "'#{value}'"
        else
          super
        end
      else
        super
      end
    end if AR42
    private :_quote if AR42

    # Quotes a string, escaping any ' (single quote) and \ (backslash) chars.
    # @return [String]
    # @override
    def quote_string(string)
      quoted = string.gsub("'", "''")
      unless standard_conforming_strings?
        quoted.gsub!(/\\/, '\&\&')
      end
      quoted
    end

    # @return [String]
    def quote_bit(value)
      case value
      # NOTE: as reported with #60 this is not quite "right" :
      #  "0103" will be treated as hexadecimal string
      #  "0102" will be treated as hexadecimal string
      #  "0101" will be treated as binary string
      #  "0100" will be treated as binary string
      # ... but is kept due Rails compatibility
      when /\A[01]*\Z/ then "B'#{value}'" # Bit-string notation
      when /\A[0-9A-F]*\Z/i then "X'#{value}'" # Hexadecimal notation
      end
    end

    def quote_bit(value)
      "B'#{value}'"
    end if AR40

    def escape_bytea(string)
      return unless string
      if supports_hex_escaped_bytea?
        "\\\\x#{string.unpack("H*")[0]}"
      else
        result = ''
        string.each_byte { |c| result << sprintf('\\\\%03o', c) }
        result
      end
    end

    # @override
    def quote_table_name(name)
      schema, name_part = extract_pg_identifier_from_name(name.to_s)

      unless name_part
        quote_column_name(schema)
      else
        table_name, name_part = extract_pg_identifier_from_name(name_part)
        "#{quote_column_name(schema)}.#{quote_column_name(table_name)}"
      end
    end

    # @override
    def quote_table_name_for_assignment(table, attr)
      quote_column_name(attr)
    end if AR40

    # @override
    def quote_column_name(name)
      %("#{name.to_s.gsub("\"", "\"\"")}")
    end

    # @private
    def quote_default_value(value, column)
      # Do not quote function default values for UUID columns
      if column.type == :uuid && value =~ /\(\)/
        value
      else
        quote(value, column)
      end
    end

    # Quote date/time values for use in SQL input.
    # Includes microseconds if the value is a Time responding to `usec`.
    # @override
    def quoted_date(value)
      result = super
      if value.acts_like?(:time) && value.respond_to?(:usec)
        result = "#{result}.#{sprintf("%06d", value.usec)}"
      end
      result = "#{result.sub(/^-/, '')} BC" if value.year < 0
      result
    end if ::ActiveRecord::VERSION::MAJOR >= 3

    # @override
    def supports_disable_referential_integrity?
      true
    end

    def disable_referential_integrity
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
        idx = "#{table_name}_pkey"
        new_idx = "#{new_name}_pkey"
        execute "ALTER TABLE #{quote_table_name(seq)} RENAME TO #{quote_table_name(new_seq)}"
        execute "ALTER INDEX #{quote_table_name(idx)} RENAME TO #{quote_table_name(new_idx)}"
      end
      rename_table_indexes(table_name, new_name) if respond_to?(:rename_table_indexes) # AR-4.0 SchemaStatements
    end

    # Adds a new column to the named table.
    # See TableDefinition#column for details of the options you can use.
    def add_column(table_name, column_name, type, options = {})
      default = options[:default]
      notnull = options[:null] == false

      sql_type = type_to_sql(type, options[:limit], options[:precision], options[:scale])
      sql_type << "[]" if options[:array]

      # Add the column.
      execute("ALTER TABLE #{quote_table_name(table_name)} ADD COLUMN #{quote_column_name(column_name)} #{sql_type}")

      change_column_default(table_name, column_name, default) if options_include_default?(options)
      change_column_null(table_name, column_name, false, default) if notnull
    end if ::ActiveRecord::VERSION::MAJOR < 4

    # @private documented above
    def add_column(table_name, column_name, type, options = {}); super end if AR42

    # Changes the column of a table.
    def change_column(table_name, column_name, type, options = {})
      quoted_table_name = quote_table_name(table_name)
      quoted_column_name = quote_table_name(column_name)

      sql_type = type_to_sql(type, options[:limit], options[:precision], options[:scale])
      sql_type << "[]" if options[:array]

      sql = "ALTER TABLE #{quoted_table_name} ALTER COLUMN #{quoted_column_name} TYPE #{sql_type}"
      sql << " USING #{options[:using]}" if options[:using]
      if options[:cast_as]
        sql << " USING CAST(#{quoted_column_name} AS #{type_to_sql(options[:cast_as], options[:limit], options[:precision], options[:scale])})"
      end
      begin
        execute sql
      rescue ActiveRecord::StatementInvalid => e
        raise e if postgresql_version > 80000
        change_column_pg7(table_name, column_name, type, options)
      end

      change_column_default(table_name, column_name, options[:default]) if options_include_default?(options)
      change_column_null(table_name, column_name, options[:null], options[:default]) if options.key?(:null)
    end # unless const_defined? :SchemaCreation

    def change_column_pg7(table_name, column_name, type, options)
      quoted_table_name = quote_table_name(table_name)
      # This is PostgreSQL 7.x, so we have to use a more arcane way of doing it.
      begin
        begin_db_transaction
        tmp_column_name = "#{column_name}_ar_tmp"
        add_column(table_name, tmp_column_name, type, options)
        execute "UPDATE #{quoted_table_name} SET #{quote_column_name(tmp_column_name)} = CAST(#{quote_column_name(column_name)} AS #{sql_type})"
        remove_column(table_name, column_name)
        rename_column(table_name, tmp_column_name, column_name)
        commit_db_transaction
      rescue
        rollback_db_transaction
      end
    end
    private :change_column_pg7

    # Changes the default value of a table column.
    def change_column_default(table_name, column_name, default)
      if column = column_for(table_name, column_name) # (backwards) compatible with AR 3.x - 4.x
        execute "ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} SET DEFAULT #{quote_default_value(default, column)}"
      else
        execute "ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} SET DEFAULT #{quote(default)}"
      end
    end unless AR42 # unless const_defined? :SchemaCreation

    # @private documented above
    def change_column_default(table_name, column_name, default)
      return unless column = column_for(table_name, column_name)

      alter_column_query = "ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} %s"
      if default.nil?
        # <tt>DEFAULT NULL</tt> results in the same behavior as <tt>DROP DEFAULT</tt>. However, PostgreSQL will
        # cast the default to the columns type, which leaves us with a default like "default NULL::character varying".
        execute alter_column_query % "DROP DEFAULT"
      else
        execute alter_column_query % "SET DEFAULT #{quote_default_value(default, column)}"
      end
    end if AR42

    # @private
    def change_column_null(table_name, column_name, null, default = nil)
      unless null || default.nil?
        if column = column_for(table_name, column_name) # (backwards) compatible with AR 3.x - 4.x
          execute "UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote_default_value(default, column)} WHERE #{quote_column_name(column_name)} IS NULL"
        else
          execute "UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL"
        end
      end
      execute("ALTER TABLE #{quote_table_name(table_name)} ALTER #{quote_column_name(column_name)} #{null ? 'DROP' : 'SET'} NOT NULL")
    end unless AR42 # unless const_defined? :SchemaCreation

    # @private
    def change_column_null(table_name, column_name, null, default = nil)
      unless null || default.nil?
        column = column_for(table_name, column_name)
        execute("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote_default_value(default, column)} WHERE #{quote_column_name(column_name)} IS NULL") if column
      end
      execute("ALTER TABLE #{quote_table_name(table_name)} ALTER #{quote_column_name(column_name)} #{null ? 'DROP' : 'SET'} NOT NULL")
    end if AR42

    def rename_column(table_name, column_name, new_column_name)
      execute "ALTER TABLE #{quote_table_name(table_name)} RENAME COLUMN #{quote_column_name(column_name)} TO #{quote_column_name(new_column_name)}"
      rename_column_indexes(table_name, column_name, new_column_name) if respond_to?(:rename_column_indexes) # AR-4.0 SchemaStatements
    end # unless const_defined? :SchemaCreation

    def add_index(table_name, column_name, options = {})
      index_name, index_type, index_columns, index_options, index_algorithm, index_using = add_index_options(table_name, column_name, options)
      execute "CREATE #{index_type} INDEX #{index_algorithm} #{quote_column_name(index_name)} ON #{quote_table_name(table_name)} #{index_using} (#{index_columns})#{index_options}"
    end if AR40

    def remove_index!(table_name, index_name)
      execute "DROP INDEX #{quote_table_name(index_name)}"
    end

    def rename_index(table_name, old_name, new_name)
      validate_index_length!(table_name, new_name) if respond_to?(:validate_index_length!)

      execute "ALTER INDEX #{quote_column_name(old_name)} RENAME TO #{quote_table_name(new_name)}"
    end

    # @override
    def supports_foreign_keys?; true end

    def foreign_keys(table_name)
      fk_info = select_all "" <<
        "SELECT t2.oid::regclass::text AS to_table, a1.attname AS column, a2.attname AS primary_key, c.conname AS name, c.confupdtype AS on_update, c.confdeltype AS on_delete " <<
        "FROM pg_constraint c " <<
        "JOIN pg_class t1 ON c.conrelid = t1.oid " <<
        "JOIN pg_class t2 ON c.confrelid = t2.oid " <<
        "JOIN pg_attribute a1 ON a1.attnum = c.conkey[1] AND a1.attrelid = t1.oid " <<
        "JOIN pg_attribute a2 ON a2.attnum = c.confkey[1] AND a2.attrelid = t2.oid " <<
        "JOIN pg_namespace t3 ON c.connamespace = t3.oid " <<
        "WHERE c.contype = 'f' " <<
        "  AND t1.relname = #{quote(table_name)} " <<
        "  AND t3.nspname = ANY (current_schemas(false)) " <<
        "ORDER BY c.conname "

      fk_info.map! do |row|
        options = {
          :column => row['column'], :name => row['name'], :primary_key => row['primary_key']
        }
        options[:on_delete] = extract_foreign_key_action(row['on_delete'])
        options[:on_update] = extract_foreign_key_action(row['on_update'])

        ForeignKeyDefinition.new(table_name, row['to_table'], options)
      end
    end if defined? ForeignKeyDefinition

    # @private
    def extract_foreign_key_action(specifier)
      case specifier
      when 'c'; :cascade
      when 'n'; :nullify
      when 'r'; :restrict
      end
    end
    private :extract_foreign_key_action

    def index_name_length
      63
    end

    # Returns the list of all column definitions for a table.
    def columns(table_name, name = nil)
      column = jdbc_column_class
      column_definitions(table_name).map! do |row|
        # |name, type, default, notnull, oid, fmod|
        name = row[0]; type = row[1]; default = row[2]
        notnull = row[3]; oid = row[4]; fmod = row[5]
        # oid = OID::TYPE_MAP.fetch(oid.to_i, fmod.to_i) { OID::Identity.new }
        notnull = notnull == 't' if notnull.is_a?(String) # JDBC gets true/false
        # for ID columns we get a bit of non-sense default :
        # e.g. "nextval('mixed_cases_id_seq'::regclass"
        if default =~ /^nextval\(.*?\:\:regclass\)$/
          default = nil
        elsif default =~ /^\(([-+]?[\d\.]+)\)$/ # e.g. "(-1)" for a negative default
          default = $1
        end

        column.new(name, default, oid, type, ! notnull, fmod, self)
      end
    end

    # @private documented above
    def columns(table_name)
      column = jdbc_column_class
      # Limit, precision, and scale are all handled by the superclass.
      column_definitions(table_name).map! do |row|
        # |name, type, default, notnull, oid, fmod|
        name = row[0]; type = row[1]; default = row[2]
        notnull = row[3]; oid = row[4]; fmod = row[5]
        notnull = notnull == 't' if notnull.is_a?(String) # JDBC gets true/false

        oid_type = get_oid_type(oid.to_i, fmod.to_i, name, type)
        default_value = extract_value_from_default(oid, default)
        default_function = extract_default_function(default_value, default)

        column.new(name, default_value, oid_type, type, ! notnull, default_function, oid, self)
      end
    end if AR42

    # @private only for API compatibility
    def new_column(name, default, cast_type, sql_type = nil, null = true, default_function = nil)
      jdbc_column_class.new(name, default, cast_type, sql_type, null, default_function)
    end if AR42

    # @private
    def column_for(table_name, column_name)
      column_name = column_name.to_s
      for column in columns(table_name)
        return column if column.name == column_name
      end
      nil
    end

    # Returns the list of a table's column names, data types, and default values.
    #
    # If the table name is not prefixed with a schema, the database will
    # take the first match from the schema search path.
    #
    # Query implementation notes:
    #  - format_type includes the column size constraint, e.g. varchar(50)
    #  - ::regclass is a function that gives the id for a table name
    def column_definitions(table_name)
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

    # @private
    TABLES_SQL = 'SELECT tablename FROM pg_tables WHERE schemaname = ANY (current_schemas(false))'
    private_constant :TABLES_SQL rescue nil

    # @override
    def tables(name = nil)
      select_values(TABLES_SQL, 'SCHEMA')
    end

    # @private
    TABLE_EXISTS_SQL_PREFIX =  'SELECT COUNT(*) as table_count FROM pg_class c'
    TABLE_EXISTS_SQL_PREFIX << ' LEFT JOIN pg_namespace n ON n.oid = c.relnamespace'
    if AR42 # -- (r)elation/table, (v)iew, (m)aterialized view
    TABLE_EXISTS_SQL_PREFIX << " WHERE c.relkind IN ('r','v','m')"
    else
    TABLE_EXISTS_SQL_PREFIX << " WHERE c.relkind IN ('r','v')"
    end
    TABLE_EXISTS_SQL_PREFIX << " AND c.relname = ?"
    private_constant :TABLE_EXISTS_SQL_PREFIX rescue nil

    # Returns true if table exists.
    # If the schema is not specified as part of +name+ then it will only find tables within
    # the current schema search path (regardless of permissions to access tables in other schemas)
    def table_exists?(name)
      schema, table = extract_schema_and_table(name.to_s)
      return false unless table

      binds = [[nil, table]]
      binds << [nil, schema] if schema

      sql = "#{TABLE_EXISTS_SQL_PREFIX} AND n.nspname = #{schema ? "?" : 'ANY (current_schemas(false))'}"

      log(sql, 'SCHEMA', binds) do
        @connection.execute_query_raw(sql, binds).first['table_count'] > 0
      end
    end
    alias data_source_exists? table_exists?

    # @private
    DATA_SOURCES_SQL =  'SELECT c.relname FROM pg_class c'
    DATA_SOURCES_SQL << ' LEFT JOIN pg_namespace n ON n.oid = c.relnamespace'
    DATA_SOURCES_SQL << " WHERE c.relkind IN ('r', 'v','m')" # -- (r)elation/table, (v)iew, (m)aterialized view
    DATA_SOURCES_SQL << ' AND n.nspname = ANY (current_schemas(false))'
    private_constant :DATA_SOURCES_SQL rescue nil

    # @override
    def data_sources
      select_values(DATA_SOURCES_SQL, 'SCHEMA')
    end

    def drop_table(table_name, options = {})
      execute "DROP TABLE #{quote_table_name(table_name)}#{' CASCADE' if options[:force] == :cascade}"
    end

    def truncate(table_name, name = nil)
      execute "TRUNCATE TABLE #{quote_table_name(table_name)}", name
    end

    def index_name_exists?(table_name, index_name, default)
      exec_query(<<-SQL, 'SCHEMA').rows.first[0].to_i > 0
        SELECT COUNT(*)
        FROM pg_class t
        INNER JOIN pg_index d ON t.oid = d.indrelid
        INNER JOIN pg_class i ON d.indexrelid = i.oid
        WHERE i.relkind = 'i'
          AND i.relname = '#{index_name}'
          AND t.relname = '#{table_name}'
          AND i.relnamespace IN (SELECT oid FROM pg_namespace WHERE nspname = ANY (current_schemas(false)) )
      SQL
    end if AR42

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

        unless column_names.empty?
          # add info on sort order for columns (only desc order is explicitly specified, asc is the default)
          desc_order_columns = inddef.scan(/(\w+) DESC/).flatten
          orders = desc_order_columns.any? ? Hash[ desc_order_columns.map { |column| [column, :desc] } ] : {}

          if ::ActiveRecord::VERSION::MAJOR > 3 # AR4 supports `where` and `using` index options
            where = inddef.scan(/WHERE (.+)$/).flatten[0]
            using = inddef.scan(/USING (.+?) /).flatten[0].to_sym

            IndexDefinition.new(table_name, index_name, unique, column_names, [], orders, where, nil, using)
          else
            new_index_definition(table_name, index_name, unique, column_names, [], orders)
          end
        end
      end
      result.compact!
      result
    end

    # @private
    def column_name_for_operation(operation, node)
      case operation
      when 'maximum' then 'max'
      when 'minimum' then 'min'
      when 'average' then 'avg'
      else operation.downcase
      end
    end if AR42

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

    # @private `Utils.extract_schema_and_table` from AR
    def extract_schema_and_table(name)
      result = name.scan(/[^".\s]+|"[^"]*"/)[0, 2]
      result.each { |m| m.gsub!(/(^"|"$)/, '') }
      result.unshift(nil) if result.size == 1 # schema == nil
      result # [schema, table]
    end

    def extract_pg_identifier_from_name(name)
      match_data = name[0, 1] == '"' ? name.match(/\"([^\"]+)\"/) : name.match(/([^\.]+)/)

      if match_data
        rest = name[match_data[0].length..-1]
        rest = rest[1..-1] if rest[0, 1] == "."
        [match_data[1], (rest.length > 0 ? rest : nil)]
      end
    end

    def extract_table_ref_from_insert_sql(sql)
      sql[/into\s+([^\(]*).*values\s*\(/i]
      $1.strip if $1
    end

    def local_tz
      @local_tz ||= execute('SHOW TIME ZONE', 'SCHEMA').first["TimeZone"]
    end

  end
end

require 'arjdbc/util/quoted_cache'

module ActiveRecord::ConnectionAdapters

  remove_const(:PostgreSQLColumn) if const_defined?(:PostgreSQLColumn)

  class PostgreSQLColumn < JdbcColumn
    include ::ArJdbc::PostgreSQL::Column
  end

  # NOTE: seems needed on 4.x due loading of '.../postgresql/oid' which
  # assumes: class PostgreSQLAdapter < AbstractAdapter
  remove_const(:PostgreSQLAdapter) if const_defined?(:PostgreSQLAdapter)

  class PostgreSQLAdapter < JdbcAdapter
    include ::ArJdbc::PostgreSQL
    include ::ArJdbc::PostgreSQL::ExplainSupport

    require 'arjdbc/postgresql/oid_types' if ::ArJdbc::AR40
    include ::ArJdbc::PostgreSQL::OIDTypes if ::ArJdbc::PostgreSQL.const_defined?(:OIDTypes)

    load 'arjdbc/postgresql/_bc_time_cast_patch.rb' if ::ArJdbc::AR42

    include ::ArJdbc::PostgreSQL::ColumnHelpers if ::ArJdbc::AR42

    include ::ArJdbc::Util::QuotedCache

    def initialize(*args)
      # @local_tz is initialized as nil to avoid warnings when connect tries to use it
      @local_tz = nil

      super # configure_connection happens in super

      @table_alias_length = nil

      initialize_type_map(@type_map = Type::HashLookupTypeMap.new) if ::ArJdbc::AR42

      @use_insert_returning = @config.key?(:insert_returning) ?
        self.class.type_cast_config_to_boolean(@config[:insert_returning]) : nil
    end

    if ::ArJdbc::AR42
      require 'active_record/connection_adapters/postgresql/schema_definitions'
    else
      require 'arjdbc/postgresql/base/schema_definitions'
    end

    ColumnDefinition = ActiveRecord::ConnectionAdapters::PostgreSQL::ColumnDefinition

    ColumnMethods = ActiveRecord::ConnectionAdapters::PostgreSQL::ColumnMethods
    TableDefinition = ActiveRecord::ConnectionAdapters::PostgreSQL::TableDefinition

    def table_definition(*args)
      new_table_definition(TableDefinition, *args)
    end

    Table = ActiveRecord::ConnectionAdapters::PostgreSQL::Table

    def update_table_definition(table_name, base)
      Table.new(table_name, base)
    end if ::ActiveRecord::VERSION::MAJOR > 3

    def jdbc_connection_class(spec)
      ::ArJdbc::PostgreSQL.jdbc_connection_class
    end

    if ::ActiveRecord::VERSION::MAJOR < 4 # Rails 3.x compatibility
      PostgreSQLJdbcConnection.raw_array_type = true if PostgreSQLJdbcConnection.raw_array_type? == nil
      PostgreSQLJdbcConnection.raw_hstore_type = true if PostgreSQLJdbcConnection.raw_hstore_type? == nil
    end

  end
end

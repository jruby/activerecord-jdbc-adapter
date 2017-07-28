# frozen_string_literal: false
ArJdbc.load_java_part :PostgreSQL

require 'ipaddr'
require 'active_record/connection_adapters/postgresql/column'
require 'active_record/connection_adapters/postgresql/database_statements'
require 'active_record/connection_adapters/postgresql/explain_pretty_printer'
require 'active_record/connection_adapters/postgresql/quoting'
require 'active_record/connection_adapters/postgresql/schema_dumper'
require 'active_record/connection_adapters/postgresql/schema_statements'
require 'active_record/connection_adapters/postgresql/type_metadata'
require 'active_record/connection_adapters/postgresql/utils'
require 'arjdbc/common_jdbc_methods'
require 'arjdbc/abstract/database_statements'
require 'arjdbc/abstract/transaction_support'
require 'arjdbc/postgresql/base/array_decoder'
require 'arjdbc/postgresql/base/array_encoder'
require 'arjdbc/postgresql/name'

module ArJdbc
  # Strives to provide Rails built-in PostgreSQL adapter (API) compatibility.
  module PostgreSQL

    require 'arjdbc/postgresql/column'
    require 'arel/visitors/postgresql_jdbc'
    # @private
    IndexDefinition = ::ActiveRecord::ConnectionAdapters::IndexDefinition

    # @private
    ForeignKeyDefinition = ::ActiveRecord::ConnectionAdapters::ForeignKeyDefinition

    # @private
    Type = ::ActiveRecord::Type

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

    NATIVE_DATABASE_TYPES = {
      :primary_key => "serial primary key",
      :string => { :name => "character varying" },
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
      :bigserial => "bigserial",
      :bigint => { :name => "bigint" },
      :bit => { :name => "bit" },
      :bit_varying => { :name => "bit varying" },
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
      :int8range => { :name => "int8range" }
    }

    def native_database_types
      NATIVE_DATABASE_TYPES
    end

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

    def supports_ddl_transactions?; true end

    def supports_explain?; true end

    def supports_index_sort_order?; true end

    def supports_migrations?; true end

    def supports_partial_index?; true end

    def supports_primary_key?; true end # Supports finding primary key on non-Active Record tables

    def supports_savepoints?; true end

    def supports_transaction_isolation?(level = nil); true end

    def supports_views?; true end

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

    # Range data-types weren't introduced until PostgreSQL 9.2.
    def supports_ranges?
      postgresql_version >= 90200
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

    # @override due to the super method not being able to handle a missing pk and
    #           RETURNING not being included in the sql
    def exec_insert(sql, name, binds, pk = nil, sequence_name = nil)
      if pk || (sql.is_a?(String) && sql =~ /RETURNING "?\S+"?$/)
        ar_postgres_adapter_exec_insert(sql, name, binds, pk, sequence_name)
      else
        super
      end
    end

    # @note Only for "better" AR 4.0 compatibility.
    # @private
    def query(sql, name = nil)
      log(sql, name) do
        result = []
        @connection.execute_query_raw(sql, nil) do |*values|
          # We need to use #deep_dup here because it appears that
          # the java method is reusing an object in some cases
          # which makes all of the entries in the "result"
          # array end up with the same values as the last row
          result << values.deep_dup
        end
        result
      end
    end

    def last_insert_id_result(sequence_name)
      select_value("SELECT currval('#{sequence_name}')", 'SQL')
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

    def quote_bit(value)
      "B'#{value}'"
    end

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
    def quote_column_name(name)
      %("#{name.to_s.gsub("\"", "\"\"")}")
    end

    # Quote date/time values for use in SQL input.
    # Includes microseconds if the value is a Time responding to `usec`.
    # @override
    def quoted_date(value)
      result = super
      if value.acts_like?(:time) && value.respond_to?(:usec) && !AR50
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

    def remove_index!(table_name, index_name)
      execute "DROP INDEX #{quote_table_name(index_name)}"
    end

    # @override
    def supports_foreign_keys?; true end

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
      rows = select_rows(<<-end_sql, 'SCHEMA')
        SELECT a.attname, format_type(a.atttypid, a.atttypmod),
               pg_get_expr(d.adbin, d.adrelid), a.attnotnull, a.atttypid, a.atttypmod,
               (SELECT c.collname FROM pg_collation c, pg_type t
                 WHERE c.oid = a.attcollation AND t.oid = a.atttypid
                  AND a.attcollation <> t.typcollation),
               col_description(a.attrelid, a.attnum) AS comment
          FROM pg_attribute a
          LEFT JOIN pg_attrdef d ON a.attrelid = d.adrelid AND a.attnum = d.adnum
         WHERE a.attrelid = '#{quote_table_name(table_name)}'::regclass
           AND a.attnum > 0 AND NOT a.attisdropped
         ORDER BY a.attnum
      end_sql

      # Force the notnull attribute to a boolean
      rows.each do |row|
        row[3] = row[3] == 't' if row[3].is_a?(String)
      end
    end
    private :column_definitions

    def truncate(table_name, name = nil)
      execute "TRUNCATE TABLE #{quote_table_name(table_name)}", name
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
    end

    private

    def translate_exception(exception, message)
      case exception.message
      when /duplicate key value violates unique constraint/
        ::ActiveRecord::RecordNotUnique.new(message)
      when /violates foreign key constraint/
        ::ActiveRecord::InvalidForeignKey.new(message)
      when /value too long/
        ::ActiveRecord::ValueTooLong.new(message)
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

  # NOTE: seems needed on 4.x due loading of '.../postgresql/oid' which
  # assumes: class PostgreSQLAdapter < AbstractAdapter
  remove_const(:PostgreSQLAdapter) if const_defined?(:PostgreSQLAdapter)

  class PostgreSQLAdapter < JdbcAdapter

    # This makes it so we can use the bulk of the core logic while
    # keeping the actual database access defined in this adapter
    # These methods come from ActiveRecord::Abstract::DatabaseStatements so
    # we need to hang on to references to them because the versions in
    # ActiveRecord::ConnectionAdapters::PostgreSQL::DatabaseStatements
    # have PG gem specific implementations that override the Abstract implementations
    SAVED_METHODS = ['select_rows', 'select_value', 'select_values']
    SAVED_METHOD_PREFIX = 'abstract_adapter'

    SAVED_METHODS.each do |base_name|
      alias_method :"#{SAVED_METHOD_PREFIX}_#{base_name}", base_name
    end

    include ActiveRecord::ConnectionAdapters::PostgreSQL::ColumnDumper
    include ActiveRecord::ConnectionAdapters::PostgreSQL::DatabaseStatements
    include ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaStatements
    include ActiveRecord::ConnectionAdapters::PostgreSQL::Quoting

    # Restore saved methods
    SAVED_METHODS.each do |base_name|
      alias_method base_name, :"#{SAVED_METHOD_PREFIX}_#{base_name}"
    end

    # We need this so we can call arjdbc logic or ActiveRecord postgres adapter logic
    # to support when a sql statement already has a 'RETURNING' clause
    alias_method :ar_postgres_adapter_exec_insert, :exec_insert

    include ArJdbc::CommonJdbcMethods
    include ArJdbc::Abstract::DatabaseStatements
    include ArJdbc::Abstract::TransactionSupport
    include ArJdbc::PostgreSQL

    require 'arjdbc/postgresql/oid_types'
    include ::ArJdbc::PostgreSQL::OIDTypes

    load 'arjdbc/postgresql/_bc_time_cast_patch.rb'

    include ::ArJdbc::PostgreSQL::ColumnHelpers

    include ::ArJdbc::Util::QuotedCache

    def initialize(*args)
      # @local_tz is initialized as nil to avoid warnings when connect tries to use it
      @local_tz = nil

      super # configure_connection happens in super

      @table_alias_length = nil

      initialize_type_map(@type_map = Type::HashLookupTypeMap.new)

      @use_insert_returning = @config.key?(:insert_returning) ?
        self.class.type_cast_config_to_boolean(@config[:insert_returning]) : nil
    end

    def arel_visitor # :nodoc:
      Arel::Visitors::PostgreSQL.new(self)
    end

    require 'active_record/connection_adapters/postgresql/schema_definitions'

    ColumnDefinition = ActiveRecord::ConnectionAdapters::PostgreSQL::ColumnDefinition
    ColumnMethods = ActiveRecord::ConnectionAdapters::PostgreSQL::ColumnMethods
    TableDefinition = ActiveRecord::ConnectionAdapters::PostgreSQL::TableDefinition
    Table = ActiveRecord::ConnectionAdapters::PostgreSQL::Table

    def schema_creation # :nodoc:
      PostgreSQL::SchemaCreation.new self
    end

    def table_definition(*args)
      new_table_definition(TableDefinition, *args)
    end

    def update_table_definition(table_name, base)
      Table.new(table_name, base)
    end

    def jdbc_connection_class(spec)
      ::ArJdbc::PostgreSQL.jdbc_connection_class
    end

  end
end

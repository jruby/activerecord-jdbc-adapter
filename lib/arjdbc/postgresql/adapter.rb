# frozen_string_literal: true
ArJdbc.load_java_part :PostgreSQL

require 'ipaddr'
require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/postgresql/column'
require 'active_record/connection_adapters/postgresql/explain_pretty_printer'
require 'active_record/connection_adapters/postgresql/quoting'
require 'active_record/connection_adapters/postgresql/referential_integrity'
require 'active_record/connection_adapters/postgresql/schema_creation'
require 'active_record/connection_adapters/postgresql/schema_definitions'
require 'active_record/connection_adapters/postgresql/schema_dumper'
require 'active_record/connection_adapters/postgresql/schema_statements'
require 'active_record/connection_adapters/postgresql/type_metadata'
require 'active_record/connection_adapters/postgresql/utils'

require 'arjdbc/abstract/core'
require 'arjdbc/abstract/connection_management'
require 'arjdbc/abstract/database_statements'
require 'arjdbc/abstract/statement_cache'
require 'arjdbc/abstract/transaction_support'
require 'arjdbc/postgresql/base/array_decoder'
require 'arjdbc/postgresql/base/array_encoder'
require 'arjdbc/postgresql/name'
require 'arjdbc/postgresql/database_statements'
require 'arjdbc/postgresql/schema_statements'
require "arjdbc/postgresql/adapter_hash_config"

require 'active_model'

require "arjdbc/abstract/relation_query_attribute_monkey_patch"

module ArJdbc
  # Strives to provide Rails built-in PostgreSQL adapter (API) compatibility.
  module PostgreSQL

    require 'arjdbc/postgresql/column'
    require 'arel/visitors/postgresql_jdbc'
    # @private
    IndexDefinition = ::ActiveRecord::ConnectionAdapters::IndexDefinition

    # @private
    Type = ::ActiveRecord::Type

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#jdbc_column_class
    def jdbc_column_class; ::ActiveRecord::ConnectionAdapters::PostgreSQLColumn end

    ADAPTER_NAME = 'PostgreSQL'

    def adapter_name
      ADAPTER_NAME
    end

    def redshift?
      # SELECT version() :
      #  PostgreSQL 8.0.2 on i686-pc-linux-gnu, compiled by GCC gcc (GCC) 3.4.2 20041017 (Red Hat 3.4.2-6.fc3), Redshift 1.0.647
      if (redshift = @config[:redshift]).nil?
        redshift = !! (valid_raw_connection.database_product || '').index('Redshift')
      end
      redshift
    end
    private :redshift?

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
      self.client_min_messages = @config[:min_messages] || 'warning'
      self.schema_search_path = @config[:schema_search_path] || @config[:schema_order]

      # Use standard-conforming strings if available so we don't have to do the E'...' dance.
      set_standard_conforming_strings

      # If using Active Record's time zone support configure the connection to return
      # TIMESTAMP WITH ZONE types in UTC.
      # (SET TIME ZONE does not use an equals sign like other SET variables)
      if ActiveRecord.default_timezone == :utc
        execute("SET time zone 'UTC'", 'SCHEMA')
      elsif tz = local_tz
        execute("SET time zone '#{tz}'", 'SCHEMA')
      end unless redshift?

      # Set interval output format to ISO 8601 for ease of parsing by ActiveSupport::Duration.parse
      execute("SET intervalstyle = iso_8601", "SCHEMA")

      # SET statements from :variables config hash
      # http://www.postgresql.org/docs/8.3/static/sql-set.html
      (@config[:variables] || {}).map do |k, v|
        if v == ':default' || v == :default
          # Sets the value to the global or compile default
          execute("SET SESSION #{k} TO DEFAULT", 'SCHEMA')
        elsif ! v.nil?
          execute("SET SESSION #{k} TO #{quote(v)}", 'SCHEMA')
        end
      end

      reload_type_map
    end

    # @private
    ActiveRecordError = ::ActiveRecord::ActiveRecordError

    NATIVE_DATABASE_TYPES = {
      primary_key:  'bigserial primary key',
      bigint:       { name: 'bigint' },
      binary:       { name: 'bytea' },
      bit:          { name: 'bit' },
      bit_varying:  { name: 'bit varying' },
      boolean:      { name: 'boolean' },
      box:          { name: 'box' },
      char:         { name: 'char' },
      cidr:         { name: 'cidr' },
      circle:       { name: 'circle' },
      citext:       { name: 'citext' },
      date:         { name: 'date' },
      daterange:    { name: 'daterange' },
      datetime:     {}, # set dynamically based on datetime_type
      timestamptz:  { name: 'timestamptz' },
      decimal:      { name: 'decimal' }, # :limit => 1000
      float:        { name: 'float' },
      hstore:       { name: 'hstore' },
      inet:         { name: 'inet' },
      int4range:    { name: 'int4range' },
      int8range:    { name: 'int8range' },
      integer:      { name: 'integer', limit: 4 },
      interval:     { name: 'interval' },
      json:         { name: 'json' },
      jsonb:        { name: 'jsonb' },
      line:         { name: 'line' },
      lseg:         { name: 'lseg' },
      ltree:        { name: 'ltree' },
      macaddr:      { name: 'macaddr' },
      money:        { name: 'money' },
      numeric:      { name: 'numeric' },
      numrange:     { name: 'numrange' },
      oid:          { name: 'oid' },
      path:         { name: 'path' },
      point:        { name: 'point' },
      polygon:      { name: 'polygon' },
      string:       { name: 'character varying' },
      text:         { name: 'text' },
      time:         { name: 'time' },
      timestamp:    { name: 'timestamp' },
      tsrange:      { name: 'tsrange' },
      tstzrange:    { name: 'tstzrange' },
      tsvector:     { name: 'tsvector' },
      uuid:         { name: 'uuid' },
      xml:          { name: 'xml' },
      enum:         {} # special type https://www.postgresql.org/docs/current/datatype-enum.html
    }

    def set_standard_conforming_strings
      execute("SET standard_conforming_strings = on", "SCHEMA")
    end

    def supports_bulk_alter?
      true
    end

    def supports_index_sort_order?
      true
    end

    def supports_partitioned_indexes?
      database_version >= 110_000
    end

    def supports_partial_index?
      true
    end

    def supports_expression_index?
      true
    end

    def supports_transaction_isolation?
      true
    end

    def supports_foreign_keys?
      true
    end

    def supports_check_constraints?
      true
    end

    def supports_validate_constraints?
      true
    end

    def supports_views?
      true
    end

    def supports_datetime_with_precision?
      true
    end

    def supports_json?
      database_version >= 90200
    end

    def supports_comments?
      true
    end

    def supports_savepoints?
      true
    end

    def supports_insert_returning?
      true
    end

    def supports_insert_on_conflict?
      database_version >= 90500
    end
    alias supports_insert_on_duplicate_skip? supports_insert_on_conflict?
    alias supports_insert_on_duplicate_update? supports_insert_on_conflict?
    alias supports_insert_conflict_target? supports_insert_on_conflict?

    def supports_virtual_columns?
      database_version >= 12_00_00 # >= 12.0
    end

    def supports_identity_columns? # :nodoc:
      database_version >= 10_00_00 # >= 10.0
    end

    def supports_nulls_not_distinct?
      database_version >= 15_00_00 # >= 15.0
    end

    def index_algorithms
      { concurrently: 'CONCURRENTLY' }
    end

    def supports_ddl_transactions?
      true
    end

    def supports_advisory_locks?
      true
    end

    def supports_explain?
      true
    end

    def supports_extensions?
      database_version >= 90200
    end

    def supports_ranges?
      database_version >= 90200
    end

    def supports_materialized_views?
      database_version >= 90300
    end

    def supports_foreign_tables?
      database_version >= 90300
    end

    def supports_pgcrypto_uuid?
      database_version >= 90400
    end

    def supports_optimizer_hints?
      unless defined?(@has_pg_hint_plan)
        @has_pg_hint_plan = extension_available?("pg_hint_plan")
      end
      @has_pg_hint_plan
    end

    def supports_common_table_expressions?
      true
    end

    def supports_lazy_transactions?
      true
    end

    def get_advisory_lock(lock_id) # :nodoc:
      unless lock_id.is_a?(Integer) && lock_id.bit_length <= 63
        raise(ArgumentError, "PostgreSQL requires advisory lock ids to be a signed 64 bit integer")
      end
      query_value("SELECT pg_try_advisory_lock(#{lock_id})")
    end

    def release_advisory_lock(lock_id) # :nodoc:
      unless lock_id.is_a?(Integer) && lock_id.bit_length <= 63
        raise(ArgumentError, "PostgreSQL requires advisory lock ids to be a signed 64 bit integer")
      end
      query_value("SELECT pg_advisory_unlock(#{lock_id})")
    end

    def enable_extension(name, **)
      schema, name = name.to_s.split(".").values_at(-2, -1)
      sql = +"CREATE EXTENSION IF NOT EXISTS \"#{name}\""
      sql << " SCHEMA #{schema}" if schema

      internal_exec_query(sql).tap { reload_type_map }
    end

    # Removes an extension from the database.
    #
    # [<tt>:force</tt>]
    #   Set to +:cascade+ to drop dependent objects as well.
    #   Defaults to false.
    def disable_extension(name, force: false)
      internal_exec_query("DROP EXTENSION IF EXISTS \"#{name}\"#{' CASCADE' if force == :cascade}").tap {
        reload_type_map
      }
    end

    def extension_available?(name)
      query_value("SELECT true FROM pg_available_extensions WHERE name = #{quote(name)}", "SCHEMA")
    end

    def extension_enabled?(name)
      query_value("SELECT installed_version IS NOT NULL FROM pg_available_extensions WHERE name = #{quote(name)}", "SCHEMA")
    end

    def extensions
      internal_exec_query("SELECT extname FROM pg_extension", "SCHEMA", allow_retry: true, materialize_transactions: false).cast_values
    end

    # Returns a list of defined enum types, and their values.
    def enum_types
      query = <<~SQL
        SELECT
          type.typname AS name,
          type.OID AS oid,
          n.nspname AS schema,
          array_agg(enum.enumlabel ORDER BY enum.enumsortorder) AS value
        FROM pg_enum AS enum
        JOIN pg_type AS type ON (type.oid = enum.enumtypid)
        JOIN pg_namespace n ON type.typnamespace = n.oid
        WHERE n.nspname = ANY (current_schemas(false))
        GROUP BY type.OID, n.nspname, type.typname;
      SQL

      internal_exec_query(query, "SCHEMA", allow_retry: true, materialize_transactions: false).cast_values.each_with_object({}) do |row, memo|
        name, schema = row[0], row[2]
        schema = nil if schema == current_schema
        full_name = [schema, name].compact.join(".")
        memo[full_name] = row.last
      end.to_a
    end

    # Given a name and an array of values, creates an enum type.
    def create_enum(name, values, **options)
      sql_values = values.map { |s| quote(s) }.join(", ")
      scope = quoted_scope(name)
      query = <<~SQL
        DO $$
        BEGIN
            IF NOT EXISTS (
              SELECT 1
              FROM pg_type t
              JOIN pg_namespace n ON t.typnamespace = n.oid
              WHERE t.typname = #{scope[:name]}
                AND n.nspname = #{scope[:schema]}
            ) THEN
                CREATE TYPE #{quote_table_name(name)} AS ENUM (#{sql_values});
            END IF;
        END
        $$;
      SQL

      internal_exec_query(query).tap { reload_type_map }
    end

    # Drops an enum type.
    #
    # If the <tt>if_exists: true</tt> option is provided, the enum is dropped
    # only if it exists. Otherwise, if the enum doesn't exist, an error is
    # raised.
    #
    # The +values+ parameter will be ignored if present. It can be helpful
    # to provide this in a migration's +change+ method so it can be reverted.
    # In that case, +values+ will be used by #create_enum.
    def drop_enum(name, values = nil, **options)
      query = <<~SQL
        DROP TYPE#{' IF EXISTS' if options[:if_exists]} #{quote_table_name(name)};
      SQL
      internal_exec_query(query).tap { reload_type_map }
    end

    # Rename an existing enum type to something else.
    def rename_enum(name, options = {})
      to = options.fetch(:to) { raise ArgumentError, ":to is required" }

      exec_query("ALTER TYPE #{quote_table_name(name)} RENAME TO #{to}").tap { reload_type_map }
    end

    # Add enum value to an existing enum type.
    def add_enum_value(type_name, value, options = {})
      before, after = options.values_at(:before, :after)
      sql = +"ALTER TYPE #{quote_table_name(type_name)} ADD VALUE '#{value}'"

      if before && after
        raise ArgumentError, "Cannot have both :before and :after at the same time"
      elsif before
        sql << " BEFORE '#{before}'"
      elsif after
        sql << " AFTER '#{after}'"
      end

      execute(sql).tap { reload_type_map }
    end

    # Rename enum value on an existing enum type.
    def rename_enum_value(type_name, options = {})
      unless database_version >= 10_00_00 # >= 10.0
        raise ArgumentError, "Renaming enum values is only supported in PostgreSQL 10 or later"
      end

      from = options.fetch(:from) { raise ArgumentError, ":from is required" }
      to = options.fetch(:to) { raise ArgumentError, ":to is required" }

      execute("ALTER TYPE #{quote_table_name(type_name)} RENAME VALUE '#{from}' TO '#{to}'").tap {
        reload_type_map
      }
    end

    # Returns the configured supported identifier length supported by PostgreSQL
    def max_identifier_length
      @max_identifier_length ||= query_value("SHOW max_identifier_length", "SCHEMA").to_i
    end

    # Set the authorized user for this session
    def session_auth=(user)
      clear_cache!
      execute("SET SESSION AUTHORIZATION #{user}")
    end

    def use_insert_returning?
      @use_insert_returning
    end

    def get_database_version # :nodoc:
      begin
        version = valid_raw_connection.database_product
        if match = version.match(/([\d\.]*\d).*?/)
          version = match[1].split('.').map(&:to_i)
          # PostgreSQL version representation does not have more than 4 digits
          # From version 10 onwards, PG has changed its versioning policy to
          # limit it to only 2 digits. i.e. in 10.x, 10 being the major
          # version and x representing the patch release
          # Refer to:
          #   https://www.postgresql.org/support/versioning/
          #   https://www.postgresql.org/docs/10/static/libpq-status.html -> PQserverVersion()
          # for more info

          if version.size >= 3
            (version[0] * 100 + version[1]) * 100 + version[2]
          elsif version.size == 2
            if version[0] >= 10
              version[0] * 100 * 100 + version[1]
            else
              (version[0] * 100 + version[1]) * 100
            end
          elsif version.size == 1
            version[0] * 100 * 100
          else
            0
          end
        else
          0
        end
      end
    end

    def default_index_type?(index) # :nodoc:
      index.using == :btree || super
    end

    def build_insert_sql(insert) # :nodoc:
      sql = +"INSERT #{insert.into} #{insert.values_list}"

      if insert.skip_duplicates?
        sql << " ON CONFLICT #{insert.conflict_target} DO NOTHING"
      elsif insert.update_duplicates?
        sql << " ON CONFLICT #{insert.conflict_target} DO UPDATE SET "
        sql << insert.touch_model_timestamps_unless { |column| "#{insert.model.quoted_table_name}.#{column} IS NOT DISTINCT FROM excluded.#{column}" }
        sql << insert.updatable_columns.map { |column| "#{column}=excluded.#{column}" }.join(",")
      end

      sql << " RETURNING #{insert.returning}" if insert.returning
      sql
    end

    def check_version # :nodoc:
      if database_version < 90300
        raise "Your version of PostgreSQL (#{database_version}) is too old. Active Record supports PostgreSQL >= 9.3."
      end
    end

    def exec_insert(sql, name = nil, binds = [], pk = nil, sequence_name = nil, returning: nil) # :nodoc:
      val = super
      if !use_insert_returning? && pk
        unless sequence_name
          table_ref = extract_table_ref_from_insert_sql(sql)
          sequence_name = default_sequence_name(table_ref, pk)
          return val unless sequence_name
        end
        last_insert_id_result(sequence_name)
      else
        val
      end
    end

    def execute_batch(statements, name = nil)
      execute(combine_multi_statements(statements), name)
    end

    # from ActiveRecord::ConnectionAdapters::PostgreSQL::DatabaseStatements
    READ_QUERY = ActiveRecord::ConnectionAdapters::AbstractAdapter.build_read_query_regexp(
      :close, :declare, :fetch, :move, :set, :show
    ) # :nodoc:
    private_constant :READ_QUERY

    def write_query?(sql) # :nodoc:
      !READ_QUERY.match?(sql)
    end

    # We need to make sure to deallocate all the prepared statements
    # since apparently calling close on the statement object
    # doesn't always free the server resources and calling
    # 'DISCARD ALL' fails if we are inside a transaction
    # def clear_cache!
    #   super
    #   # Make sure all query plans are *really* gone
    #   @connection.execute 'DEALLOCATE ALL' if active?
    # end

    def reset!
      @lock.synchronize do
        return connect! unless @raw_connection

        # Have to deal with rollbacks differently than the AR adapter
        @raw_connection.rollback

        @raw_connection.execute("DISCARD ALL")

        super
      end
    end

    # Disconnects from the database if already connected. Otherwise, this
    # method does nothing.
    def disconnect!
      @lock.synchronize do
        super
        @raw_connection&.close
        @raw_connection = nil
      end
    end

    def default_sequence_name(table_name, pk = "id") #:nodoc:
      serial_sequence(table_name, pk)
    rescue ActiveRecord::StatementInvalid
      %Q("#{table_name}_#{pk}_seq")
    end

    def last_insert_id_result(sequence_name)
      exec_query("SELECT currval('#{sequence_name}')", 'SQL')
    end

    def build_truncate_statements(table_names)
      ["TRUNCATE TABLE #{table_names.map(&method(:quote_table_name)).join(", ")}"]
    end

    def all_schemas
      select('SELECT nspname FROM pg_namespace').map { |row| row["nspname"] }
    end

    # Returns the current client message level.
    def client_min_messages
      return nil if redshift? # not supported on Redshift
      # Need to use #execute so we don't try to access the type map before it is initialized
      execute('SHOW client_min_messages', 'SCHEMA').values.first.first
    end

    # Set the client message level.
    def client_min_messages=(level)
      # Not supported on Redshift
      redshift? ? nil : super
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

    # @note #quote_string implemented as native

    def escape_bytea(string)
      return unless string
      "\\x#{string.unpack("H*")[0]}"
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

    # @note #quote_column_name implemented as native
    alias_method :quote_schema_name, :quote_column_name

    # Need to clear the cache even though the AR adapter doesn't for some reason
    def remove_column(table_name, column_name, type = nil, **options)
      super
      clear_cache!
    end

    # @private
    def column_for(table_name, column_name)
      column_name = column_name.to_s
      for column in columns(table_name)
        return column if column.name == column_name
      end
      nil
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

    # Returns the list of a table's column names, data types, and default values.
    #
    # The underlying query is roughly:
    #  SELECT column.name, column.type, default.value, column.comment
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
    def column_definitions(table_name)
      query(<<~SQL, "SCHEMA")
          SELECT a.attname, format_type(a.atttypid, a.atttypmod),
                 pg_get_expr(d.adbin, d.adrelid), a.attnotnull, a.atttypid, a.atttypmod,
                 c.collname, col_description(a.attrelid, a.attnum) AS comment,
                 #{supports_identity_columns? ? 'attidentity' : quote('')} AS identity,
                 #{supports_virtual_columns? ? 'attgenerated' : quote('')} as attgenerated
            FROM pg_attribute a
            LEFT JOIN pg_attrdef d ON a.attrelid = d.adrelid AND a.attnum = d.adnum
            LEFT JOIN pg_type t ON a.atttypid = t.oid
            LEFT JOIN pg_collation c ON a.attcollation = c.oid AND a.attcollation <> t.typcollation
           WHERE a.attrelid = #{quote(quote_table_name(table_name))}::regclass
             AND a.attnum > 0 AND NOT a.attisdropped
           ORDER BY a.attnum
      SQL
    end

    def extract_table_ref_from_insert_sql(sql)
      sql[/into\s("[A-Za-z0-9_."\[\]\s]+"|[A-Za-z0-9_."\[\]]+)\s*/im]
      $1.strip if $1
    end

    def arel_visitor
      Arel::Visitors::PostgreSQL.new(self)
    end

    # Pulled from ActiveRecord's Postgres adapter and modified to use execute
    def can_perform_case_insensitive_comparison_for?(column)
      # NOTE: citext is an exception. It is possible to perform a
      #       case-insensitive comparison using `LOWER()`, but it is
      #       unnecessary, as `citext` is case-insensitive by definition.
      @case_insensitive_cache ||= { "citext" => false }
      @case_insensitive_cache.fetch(column.sql_type) do
        @case_insensitive_cache[column.sql_type] = begin
          sql = <<~SQL
            SELECT exists(
              SELECT * FROM pg_proc
              WHERE proname = 'lower'
                AND proargtypes = ARRAY[#{quote column.sql_type}::regtype]::oidvector
            ) OR exists(
              SELECT * FROM pg_proc
              INNER JOIN pg_cast
                ON ARRAY[casttarget]::oidvector = proargtypes
              WHERE proname = 'lower'
                AND castsource = #{quote column.sql_type}::regtype
            )
          SQL
          select_value(sql, 'SCHEMA')
        end
      end
    end

    def translate_exception(exception, message:, sql:, binds:)
      return super unless exception.is_a?(ActiveRecord::JDBCError)

      # TODO: Can we base these on an error code of some kind?
      case exception.message
      when /could not create unique index/
        ::ActiveRecord::RecordNotUnique.new(message, sql: sql, binds: binds, connection_pool: @pool)
      when /duplicate key value violates unique constraint/
        ::ActiveRecord::RecordNotUnique.new(message, sql: sql, binds: binds)
      when /violates not-null constraint/
        ::ActiveRecord::NotNullViolation.new(message, sql: sql, binds: binds)
      when /violates foreign key constraint/
        ::ActiveRecord::InvalidForeignKey.new(message, sql: sql, binds: binds)
      when /value too long/
        ::ActiveRecord::ValueTooLong.new(message, sql: sql, binds: binds)
      when /out of range/
        ::ActiveRecord::RangeError.new(message, sql: sql, binds: binds)
      when /could not serialize/
        ::ActiveRecord::SerializationFailure.new(message, sql: sql, binds: binds)
      when /deadlock detected/
        ::ActiveRecord::Deadlocked.new(message, sql: sql, binds: binds)
      when /lock timeout/
        ::ActiveRecord::LockWaitTimeout.new(message, sql: sql, binds: binds)
      when /canceling statement/ # This needs to come after lock timeout because the lock timeout message also contains "canceling statement"
        ::ActiveRecord::QueryCanceled.new(message, sql: sql, binds: binds)
      when /relation .* does not exist/i
        ::ActiveRecord::StatementInvalid.new(message, sql: sql, binds: binds, connection_pool: @pool)
      when /syntax error at or near/i
        ::ActiveRecord::StatementInvalid.new(message, sql: sql, binds: binds, connection_pool: @pool)
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

    def local_tz
      @local_tz ||= execute('SHOW TIME ZONE', 'SCHEMA').first["TimeZone"]
    end

    def bind_params_length
      32767
    end

  end
end

require 'arjdbc/util/quoted_cache'

module ActiveRecord::ConnectionAdapters

  # NOTE: seems needed on 4.x due loading of '.../postgresql/oid' which
  # assumes: class PostgreSQLAdapter < AbstractAdapter
  remove_const(:PostgreSQLAdapter) if const_defined?(:PostgreSQLAdapter)

  class PostgreSQLAdapter < AbstractAdapter
    class_attribute :create_unlogged_tables, default: false

    ##
    # :singleton-method:
    # PostgreSQL allows the creation of "unlogged" tables, which do not record
    # data in the PostgreSQL Write-Ahead Log. This can make the tables faster,
    # but significantly increases the risk of data loss if the database
    # crashes. As a result, this should not be used in production
    # environments. If you would like all created tables to be unlogged in
    # the test environment you can add the following line to your test.rb
    # file:
    #
    #   ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.create_unlogged_tables = true
    class_attribute :create_unlogged_tables, default: false

    ##
    # :singleton-method:
    # PostgreSQL supports multiple types for DateTimes. By default, if you use +datetime+
    # in migrations, Rails will translate this to a PostgreSQL "timestamp without time zone".
    # Change this in an initializer to use another NATIVE_DATABASE_TYPES. For example, to
    # store DateTimes as "timestamp with time zone":
    #
    #   ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.datetime_type = :timestamptz
    #
    # Or if you are adding a custom type:
    #
    #   ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::NATIVE_DATABASE_TYPES[:my_custom_type] = { name: "my_custom_type_name" }
    #   ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.datetime_type = :my_custom_type
    #
    # If you're using +:ruby+ as your +config.active_record.schema_format+ and you change this
    # setting, you should immediately run <tt>bin/rails db:migrate</tt> to update the types in your schema.rb.
    class_attribute :datetime_type, default: :timestamp

    ##
    # :singleton-method:
    # Toggles automatic decoding of date columns.
    #
    #   ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.select_value("select '2024-01-01'::date").class #=> String
    #   ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.decode_dates = true
    #   ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.select_value("select '2024-01-01'::date").class #=> Date
    class_attribute :decode_dates, default: false

    # Try to use as much of the built in postgres logic as possible
    # maybe someday we can extend the actual adapter
    include ActiveRecord::ConnectionAdapters::PostgreSQL::ReferentialIntegrity
    include ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaStatements
    include ActiveRecord::ConnectionAdapters::PostgreSQL::Quoting

    # include Jdbc::ConnectionPoolCallbacks

    include ArJdbc::Abstract::Core
    include ArJdbc::Abstract::ConnectionManagement
    include ArJdbc::Abstract::DatabaseStatements
    include ArJdbc::Abstract::StatementCache
    include ArJdbc::Abstract::TransactionSupport
    include ArJdbc::PostgreSQLConfig

    # NOTE: after AR refactor quote_column_name became class and instance method
    include ArJdbc::PostgreSQL
    extend ArJdbc::PostgreSQL

    require 'arjdbc/postgresql/oid_types'
    include ::ArJdbc::PostgreSQL::OIDTypes
    include ::ArJdbc::PostgreSQL::DatabaseStatements
    include ::ArJdbc::PostgreSQL::SchemaStatements

    include ::ArJdbc::PostgreSQL::ColumnHelpers

    include ::ArJdbc::Util::QuotedCache

    # AR expects OID to be available on the adapter
    OID = ActiveRecord::ConnectionAdapters::PostgreSQL::OID

    class << self
      def jdbc_connection_class
        ::ActiveRecord::ConnectionAdapters::PostgreSQLJdbcConnection
      end

      def new_client(conn_params, adapter_instance)
        jdbc_connection_class.new(conn_params, adapter_instance)
      end

      def dbconsole(config, options = {})
        pg_config = config.configuration_hash

        ENV["PGUSER"]         = pg_config[:username] if pg_config[:username]
        ENV["PGHOST"]         = pg_config[:host] if pg_config[:host]
        ENV["PGPORT"]         = pg_config[:port].to_s if pg_config[:port]
        ENV["PGPASSWORD"]     = pg_config[:password].to_s if pg_config[:password] && options[:include_password]
        ENV["PGSSLMODE"]      = pg_config[:sslmode].to_s if pg_config[:sslmode]
        ENV["PGSSLCERT"]      = pg_config[:sslcert].to_s if pg_config[:sslcert]
        ENV["PGSSLKEY"]       = pg_config[:sslkey].to_s if pg_config[:sslkey]
        ENV["PGSSLROOTCERT"]  = pg_config[:sslrootcert].to_s if pg_config[:sslrootcert]
        if pg_config[:variables]
          ENV["PGOPTIONS"] = pg_config[:variables].filter_map do |name, value|
            "-c #{name}=#{value.to_s.gsub(/[ \\]/, '\\\\\0')}" unless value == ":default" || value == :default
          end.join(" ")
        end
        find_cmd_and_exec("psql", config.database)
      end
    end

    def initialize(...)
      super

      # assign arjdbc extra connection params
      conn_params = build_connection_config(@config.compact)

      @connection_parameters = conn_params

      # @local_tz is initialized as nil to avoid warnings when connect tries to use it
      @local_tz = nil
      @max_identifier_length = nil

      @use_insert_returning = @config.key?(:insert_returning) ?
        self.class.type_cast_config_to_boolean(@config[:insert_returning]) : true
    end

    require 'active_record/connection_adapters/postgresql/schema_definitions'

    ColumnMethods = ActiveRecord::ConnectionAdapters::PostgreSQL::ColumnMethods
    TableDefinition = ActiveRecord::ConnectionAdapters::PostgreSQL::TableDefinition
    Table = ActiveRecord::ConnectionAdapters::PostgreSQL::Table

    public :sql_for_insert
    alias :postgresql_version :database_version

    def native_database_types # :nodoc:
      self.class.native_database_types
    end

    def self.native_database_types # :nodoc:
      @native_database_types ||= begin
        types = NATIVE_DATABASE_TYPES.dup
        types[:datetime] = types[datetime_type]
        types
      end
    end

    private

    FEATURE_NOT_SUPPORTED = "0A000" # :nodoc:

    def execute_and_clear(sql, name, binds, prepare: false, async: false)
      sql = transform_query(sql)
      check_if_write_query(sql)

      if !prepare || without_prepared_statement?(binds)
        result = exec_no_cache(sql, name, binds, async: async)
      else
        result = exec_cache(sql, name, binds, async: async)
      end
      begin
        ret = yield result
      ensure
        # Is this really result in AR PG?
#        result.clear
      end
      ret
    end

    def exec_no_cache(sql, name, binds, async: false)
      materialize_transactions
      mark_transaction_written_if_write(sql)

      # make sure we carry over any changes to ActiveRecord.default_timezone that have been
      # made since we established the connection
      update_typemap_for_default_timezone

      type_casted_binds = type_casted_binds(binds)
      log(sql, name, binds, type_casted_binds, async: async) do
        with_raw_connection do |conn|
          result = conn.exec_params(sql, type_casted_binds)
          verified!
          result
        end
      end
    end

    def exec_cache(sql, name, binds, async: false)
      materialize_transactions
      mark_transaction_written_if_write(sql)
      update_typemap_for_default_timezone

      stmt_key = prepare_statement(sql, binds)
      type_casted_binds = type_casted_binds(binds)

      log(sql, name, binds, type_casted_binds, stmt_key, async: async) do
        ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
          @connection.exec_prepared(stmt_key, type_casted_binds)
        end
      end
    rescue ActiveRecord::StatementInvalid => e
      raise unless is_cached_plan_failure?(e)

      # Nothing we can do if we are in a transaction because all commands
      # will raise InFailedSQLTransaction
      if in_transaction?
        raise ActiveRecord::PreparedStatementCacheExpired.new(e.cause.message)
      else
        @lock.synchronize do
          # outside of transactions we can simply flush this query and retry
          @statements.delete sql_key(sql)
        end
        retry
      end
    end

    # Annoyingly, the code for prepared statements whose return value may
    # have changed is FEATURE_NOT_SUPPORTED.
    #
    # This covers various different error types so we need to do additional
    # work to classify the exception definitively as a
    # ActiveRecord::PreparedStatementCacheExpired
    #
    # Check here for more details:
    # https://git.postgresql.org/gitweb/?p=postgresql.git;a=blob;f=src/backend/utils/cache/plancache.c#l573
    def is_cached_plan_failure?(e)
      pgerror = e.cause
      pgerror.result.result_error_field(PG::PG_DIAG_SQLSTATE) == FEATURE_NOT_SUPPORTED &&
        pgerror.result.result_error_field(PG::PG_DIAG_SOURCE_FUNCTION) == "RevalidateCachedQuery"
    rescue
      false
    end

    def in_transaction?
      open_transactions > 0
    end

    # Returns the statement identifier for the client side cache
    # of statements
    def sql_key(sql)
      "#{schema_search_path}-#{sql}"
    end
  end
end

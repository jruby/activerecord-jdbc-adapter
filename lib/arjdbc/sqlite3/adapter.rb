# frozen_string_literal: true

ArJdbc.load_java_part :SQLite3

require "arjdbc/abstract/core"
require "arjdbc/abstract/database_statements"
require 'arjdbc/abstract/statement_cache'
require "arjdbc/abstract/transaction_support"
require "active_record/connection_adapters/abstract_adapter"
require "active_record/connection_adapters/statement_pool"
require "active_record/connection_adapters/sqlite3/explain_pretty_printer"
require "active_record/connection_adapters/sqlite3/quoting"
require "active_record/connection_adapters/sqlite3/schema_creation"
require "active_record/connection_adapters/sqlite3/schema_definitions"
require "active_record/connection_adapters/sqlite3/schema_dumper"
require "active_record/connection_adapters/sqlite3/schema_statements"
require "active_support/core_ext/class/attribute"

module SQLite3
  module Constants
    module Open
      READONLY       = 0x00000001
      READWRITE      = 0x00000002
      CREATE         = 0x00000004
      DELETEONCLOSE  = 0x00000008
      EXCLUSIVE      = 0x00000010
      AUTOPROXY      = 0x00000020
      URI            = 0x00000040
      MEMORY         = 0x00000080
      MAIN_DB        = 0x00000100
      TEMP_DB        = 0x00000200
      TRANSIENT_DB   = 0x00000400
      MAIN_JOURNAL   = 0x00000800
      TEMP_JOURNAL   = 0x00001000
      SUBJOURNAL     = 0x00002000
      MASTER_JOURNAL = 0x00004000
      NOMUTEX        = 0x00008000
      FULLMUTEX      = 0x00010000
      SHAREDCACHE    = 0x00020000
      PRIVATECACHE   = 0x00040000
      WAL            = 0x00080000
    end
  end
end

module ArJdbc
  # All the code in this module is a copy of ConnectionAdapters::SQLite3Adapter from active_record 5.
  # The constants at the front of this file are to allow the rest of the file to remain with no modifications
  # from its original source.  If you hack on this file try not to modify this module and instead try and
  # put those overrides in SQL3Adapter below.  We try and keep a copy of the Rails this adapter supports
  # with the current goal of being able to diff changes easily over time and to also eventually remove
  # this module from ARJDBC altogether.
  module SQLite3
    # DIFFERENCE: Some common constant names to reduce differences in rest of this module from AR5 version
    ConnectionAdapters = ::ActiveRecord::ConnectionAdapters
    IndexDefinition = ::ActiveRecord::ConnectionAdapters::IndexDefinition
    Quoting = ::ActiveRecord::ConnectionAdapters::SQLite3::Quoting
    RecordNotUnique = ::ActiveRecord::RecordNotUnique
    SchemaCreation = ConnectionAdapters::SQLite3::SchemaCreation
    SQLite3Adapter = ConnectionAdapters::AbstractAdapter

    ADAPTER_NAME = 'SQLite'

    # DIFFERENCE: FQN
    include ::ActiveRecord::ConnectionAdapters::SQLite3::Quoting
    include ::ActiveRecord::ConnectionAdapters::SQLite3::SchemaStatements

    NATIVE_DATABASE_TYPES = {
        primary_key:  "integer PRIMARY KEY AUTOINCREMENT NOT NULL",
        string:       { name: "varchar" },
        text:         { name: "text" },
        integer:      { name: "integer" },
        float:        { name: "float" },
        decimal:      { name: "decimal" },
        datetime:     { name: "datetime" },
        time:         { name: "time" },
        date:         { name: "date" },
        binary:       { name: "blob" },
        boolean:      { name: "boolean" },
        json:         { name: "json" },
    }

    # DIFFERENCE: class_attribute in original adapter is moved down to our section which is a class
    #  since we cannot define it here in the module (original source this is a class).

    def initialize(connection, logger, connection_options, config)
      super(connection, logger, config)
      configure_connection
    end

    def supports_ddl_transactions?
      true
    end

    def supports_savepoints?
      true
    end

    def supports_transaction_isolation?
      true
    end

    def supports_partial_index?
      database_version >= "3.9.0"
    end

    def supports_expression_index?
      database_version >= "3.9.0"
    end

    def requires_reloading?
      true
    end

    def supports_foreign_keys?
      true
    end

    def supports_check_constraints?
      true
    end

    def supports_views?
      true
    end

    def supports_datetime_with_precision?
      true
    end

    def supports_json?
      true
    end

    def supports_common_table_expressions?
      database_version >= "3.8.3"
    end

    def supports_insert_on_conflict?
      database_version >= "3.24.0"
    end
    alias supports_insert_on_duplicate_skip? supports_insert_on_conflict?
    alias supports_insert_on_duplicate_update? supports_insert_on_conflict?
    alias supports_insert_conflict_target? supports_insert_on_conflict?

    # DIFFERENCE: active?, reconnect!, disconnect! handles by arjdbc core

    def supports_index_sort_order?
      true
    end

    def native_database_types #:nodoc:
      NATIVE_DATABASE_TYPES
    end

    # Returns the current database encoding format as a string, eg: 'UTF-8'
    def encoding
      @connection.encoding.to_s
    end

    def supports_explain?
      true
    end

    def supports_lazy_transactions?
      true
    end

    # REFERENTIAL INTEGRITY ====================================

    def disable_referential_integrity # :nodoc:
      old_foreign_keys = query_value("PRAGMA foreign_keys")
      old_defer_foreign_keys = query_value("PRAGMA defer_foreign_keys")

      begin
        execute("PRAGMA defer_foreign_keys = ON")
        execute("PRAGMA foreign_keys = OFF")
        yield
      ensure
        execute("PRAGMA defer_foreign_keys = #{old_defer_foreign_keys}")
        execute("PRAGMA foreign_keys = #{old_foreign_keys}")
      end
    end

    #--
    # DATABASE STATEMENTS ======================================
    #++

    READ_QUERY = ActiveRecord::ConnectionAdapters::AbstractAdapter.build_read_query_regexp(
      :pragma
    ) # :nodoc:
    private_constant :READ_QUERY

    def write_query?(sql) # :nodoc:
      !READ_QUERY.match?(sql)
    end

    def explain(arel, binds = [])
      sql = "EXPLAIN QUERY PLAN #{to_sql(arel, binds)}"
      # DIFFERENCE: FQN
      ::ActiveRecord::ConnectionAdapters::SQLite3::ExplainPrettyPrinter.new.pp(exec_query(sql, "EXPLAIN", []))
    end

    # DIFFERENCE: implemented in ArJdbc::Abstract::DatabaseStatements
    #def exec_query(sql, name = nil, binds = [], prepare: false)

    # DIFFERENCE: implemented in ArJdbc::Abstract::DatabaseStatements
    #def exec_delete(sql, name = "SQL", binds = [])

    def last_inserted_id(result)
      @connection.last_insert_row_id
    end

    # DIFFERENCE: implemented in ArJdbc::Abstract::DatabaseStatements
    #def execute(sql, name = nil) #:nodoc:

    def begin_db_transaction #:nodoc:
      log("begin transaction", 'TRANSACTION') { @connection.transaction }
    end

    def commit_db_transaction #:nodoc:
      log("commit transaction", 'TRANSACTION') { @connection.commit }
    end

    def exec_rollback_db_transaction #:nodoc:
      log("rollback transaction", 'TRANSACTION') { @connection.rollback }
    end

    # SCHEMA STATEMENTS ========================================

    def primary_keys(table_name) # :nodoc:
      pks = table_structure(table_name).select { |f| f["pk"] > 0 }
      pks.sort_by { |f| f["pk"] }.map { |f| f["name"] }
    end

      def remove_index(table_name, column_name = nil, **options) # :nodoc:
        return if options[:if_exists] && !index_exists?(table_name, column_name, **options)

      index_name = index_name_for_remove(table_name, column_name, options)

      exec_query "DROP INDEX #{quote_column_name(index_name)}"
    end

    # Renames a table.
    #
    # Example:
    #   rename_table('octopuses', 'octopi')
    def rename_table(table_name, new_name)
      schema_cache.clear_data_source_cache!(table_name.to_s)
      schema_cache.clear_data_source_cache!(new_name.to_s)
      exec_query "ALTER TABLE #{quote_table_name(table_name)} RENAME TO #{quote_table_name(new_name)}"
      rename_table_indexes(table_name, new_name)
    end

    def add_column(table_name, column_name, type, **options) #:nodoc:
      if invalid_alter_table_type?(type, options)
        alter_table(table_name) do |definition|
          definition.column(column_name, type, **options)
        end
      else
        super
      end
    end

    def remove_column(table_name, column_name, type = nil, **options) #:nodoc:
      alter_table(table_name) do |definition|
        definition.remove_column column_name
        definition.foreign_keys.delete_if do |_, fk_options|
          fk_options[:column] == column_name.to_s
        end
      end
    end

    def change_column_default(table_name, column_name, default_or_changes) #:nodoc:
      default = extract_new_default_value(default_or_changes)

      alter_table(table_name) do |definition|
        definition[column_name].default = default
      end
    end

    def change_column_null(table_name, column_name, null, default = nil) #:nodoc:
      unless null || default.nil?
        exec_query("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
      end
      alter_table(table_name) do |definition|
        definition[column_name].null = null
      end
    end

    def change_column(table_name, column_name, type, **options) #:nodoc:
      alter_table(table_name) do |definition|
        definition[column_name].instance_eval do
          self.type    = type
            self.options.merge!(options)
        end
      end
    end

    def rename_column(table_name, column_name, new_column_name) #:nodoc:
      column = column_for(table_name, column_name)
      alter_table(table_name, rename: { column.name => new_column_name.to_s })
      rename_column_indexes(table_name, column.name, new_column_name)
    end

    def add_reference(table_name, ref_name, **options) # :nodoc:
      super(table_name, ref_name, type: :integer, **options)
    end
    alias :add_belongs_to :add_reference

    def foreign_keys(table_name)
      fk_info = exec_query("PRAGMA foreign_key_list(#{quote(table_name)})", "SCHEMA")
      fk_info.map do |row|
        options = {
          column: row["from"],
          primary_key: row["to"],
          on_delete: extract_foreign_key_action(row["on_delete"]),
          on_update: extract_foreign_key_action(row["on_update"])
        }
        # DIFFERENCE: FQN
        ::ActiveRecord::ConnectionAdapters::ForeignKeyDefinition.new(table_name, row["table"], options)
      end
    end

    def insert_fixtures_set(fixture_set, tables_to_delete = [])
      disable_referential_integrity do
        transaction(requires_new: true) do
          tables_to_delete.each { |table| delete "DELETE FROM #{quote_table_name(table)}", "Fixture Delete" }

          fixture_set.each do |table_name, rows|
            rows.each { |row| insert_fixture(row, table_name) }
          end
        end
      end
    end

    def build_insert_sql(insert) # :nodoc:
      sql = +"INSERT #{insert.into} #{insert.values_list}"

      if insert.skip_duplicates?
        sql << " ON CONFLICT #{insert.conflict_target} DO NOTHING"
      elsif insert.update_duplicates?
        sql << " ON CONFLICT #{insert.conflict_target} DO UPDATE SET "
        sql << insert.touch_model_timestamps_unless { |column| "#{column} IS excluded.#{column}" }
        sql << insert.updatable_columns.map { |column| "#{column}=excluded.#{column}" }.join(",")
      end

      sql
    end

    def shared_cache?
      config[:properties] && config[:properties][:shared_cache] == true
    end

    def get_database_version # :nodoc:
      SQLite3Adapter::Version.new(query_value("SELECT sqlite_version(*)"))
    end

    def build_truncate_statement(table_name)
      "DELETE FROM #{quote_table_name(table_name)}"
    end

    def check_version
      if database_version < "3.8.0"
        raise "Your version of SQLite (#{database_version}) is too old. Active Record supports SQLite >= 3.8."
      end
    end

    private
    # See https://www.sqlite.org/limits.html,
    # the default value is 999 when not configured.
    def bind_params_length
      999
    end

    def table_structure(table_name)
      structure = exec_query("PRAGMA table_info(#{quote_table_name(table_name)})", "SCHEMA")
      raise(ActiveRecord::StatementInvalid, "Could not find table '#{table_name}'") if structure.empty?
      table_structure_with_collation(table_name, structure)
    end
    alias column_definitions table_structure

    # See: https://www.sqlite.org/lang_altertable.html
    # SQLite has an additional restriction on the ALTER TABLE statement
    def invalid_alter_table_type?(type, options)
      type.to_sym == :primary_key || options[:primary_key] ||
        options[:null] == false && options[:default].nil?
    end

    def alter_table(
      table_name,
      foreign_keys = foreign_keys(table_name),
      check_constraints = check_constraints(table_name),
      **options
    )
      altered_table_name = "a#{table_name}"

      caller = lambda do |definition|
        rename = options[:rename] || {}
        foreign_keys.each do |fk|
          if column = rename[fk.options[:column]]
            fk.options[:column] = column
          end
          to_table = strip_table_name_prefix_and_suffix(fk.to_table)
          definition.foreign_key(to_table, **fk.options)
        end

        check_constraints.each do |chk|
          definition.check_constraint(chk.expression, **chk.options)
        end

        yield definition if block_given?
      end

      transaction do
        disable_referential_integrity do
          move_table(table_name, altered_table_name, options.merge(temporary: true))
          move_table(altered_table_name, table_name, &caller)
        end
      end
    end

    def move_table(from, to, options = {}, &block)
      copy_table(from, to, options, &block)
      drop_table(from)
    end

    def copy_table(from, to, options = {})
      from_primary_key = primary_key(from)
      options[:id] = false
      create_table(to, **options) do |definition|
        @definition = definition
        if from_primary_key.is_a?(Array)
          @definition.primary_keys from_primary_key
        end

        columns(from).each do |column|
          column_name = options[:rename] ?
            (options[:rename][column.name] ||
             options[:rename][column.name.to_sym] ||
             column.name) : column.name

          @definition.column(column_name, column.type,
            limit: column.limit, default: column.default,
            precision: column.precision, scale: column.scale,
            null: column.null, collation: column.collation,
            primary_key: column_name == from_primary_key
          )
        end

        yield @definition if block_given?
      end
      copy_table_indexes(from, to, options[:rename] || {})
      copy_table_contents(from, to,
        @definition.columns.map(&:name),
        options[:rename] || {})
    end

    def copy_table_indexes(from, to, rename = {})
      indexes(from).each do |index|
        name = index.name
        # indexes sqlite creates for internal use start with `sqlite_` and
        # don't need to be copied
        next if name.start_with?("sqlite_")
        if to == "a#{from}"
          name = "t#{name}"
        elsif from == "a#{to}"
          name = name[1..-1]
        end

        columns = index.columns
        if columns.is_a?(Array)
          to_column_names = columns(to).map(&:name)
          columns = columns.map { |c| rename[c] || c }.select do |column|
            to_column_names.include?(column)
          end
        end

        unless columns.empty?
          # index name can't be the same
          options = { name: name.gsub(/(^|_)(#{from})_/, "\\1#{to}_"), internal: true }
          options[:unique] = true if index.unique
          options[:where] = index.where if index.where
          add_index(to, columns, **options)
        end
      end
    end

    def copy_table_contents(from, to, columns, rename = {})
      column_mappings = Hash[columns.map { |name| [name, name] }]
      rename.each { |a| column_mappings[a.last] = a.first }
      from_columns = columns(from).collect(&:name)
      columns = columns.find_all { |col| from_columns.include?(column_mappings[col]) }
      from_columns_to_copy = columns.map { |col| column_mappings[col] }
      quoted_columns = columns.map { |col| quote_column_name(col) } * ","
      quoted_from_columns = from_columns_to_copy.map { |col| quote_column_name(col) } * ","

      exec_query("INSERT INTO #{quote_table_name(to)} (#{quoted_columns})
                     SELECT #{quoted_from_columns} FROM #{quote_table_name(from)}")
    end

    def translate_exception(exception, message:, sql:, binds:)
      case exception.message
      # SQLite 3.8.2 returns a newly formatted error message:
      #   UNIQUE constraint failed: *table_name*.*column_name*
      # Older versions of SQLite return:
      #   column *column_name* is not unique
      when /column(s)? .* (is|are) not unique/, /UNIQUE constraint failed: .*/
        # DIFFERENCE: FQN
        ::ActiveRecord::RecordNotUnique.new(message, sql: sql, binds: binds)
      when /.* may not be NULL/, /NOT NULL constraint failed: .*/
        # DIFFERENCE: FQN
        ::ActiveRecord::NotNullViolation.new(message, sql: sql, binds: binds)
      when /FOREIGN KEY constraint failed/i
        # DIFFERENCE: FQN
        ::ActiveRecord::InvalidForeignKey.new(message, sql: sql, binds: binds)
      else
        super
      end
    end

    COLLATE_REGEX = /.*\"(\w+)\".*collate\s+\"(\w+)\".*/i.freeze

    def table_structure_with_collation(table_name, basic_structure)
      collation_hash = {}
      sql = <<~SQL
        SELECT sql FROM
          (SELECT * FROM sqlite_master UNION ALL
           SELECT * FROM sqlite_temp_master)
        WHERE type = 'table' AND name = #{quote(table_name)}
      SQL

      # Result will have following sample string
      # CREATE TABLE "users" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
      #                       "password_digest" varchar COLLATE "NOCASE");
      result = exec_query(sql, "SCHEMA").first

      if result
        # Splitting with left parentheses and discarding the first part will return all
        # columns separated with comma(,).
        columns_string = result["sql"].split("(", 2).last

        columns_string.split(",").each do |column_string|
          # This regex will match the column name and collation type and will save
          # the value in $1 and $2 respectively.
          collation_hash[$1] = $2 if COLLATE_REGEX =~ column_string
        end

        basic_structure.map do |column|
          column_name = column["name"]

          if collation_hash.has_key? column_name
            column["collation"] = collation_hash[column_name]
          end

          column
        end
      else
        basic_structure.to_a
      end
    end

    def arel_visitor
      Arel::Visitors::SQLite.new(self)
    end

    def configure_connection
      execute("PRAGMA foreign_keys = ON", "SCHEMA")
    end

  end
  # DIFFERENCE: A registration here is moved down to concrete class so we are not registering part of an adapter.
end

module ActiveRecord::ConnectionAdapters
  class SQLite3Column < JdbcColumn
    def initialize(name, *args)
      if Hash === name
        super
      else
        super(nil, name, *args)
      end
    end

    def self.string_to_binary(value)
      value
    end

    def self.binary_to_string(value)
      if value.respond_to?(:encoding) && value.encoding != Encoding::ASCII_8BIT
        value = value.force_encoding(Encoding::ASCII_8BIT)
      end
      value
    end

    # @override {ActiveRecord::ConnectionAdapters::JdbcColumn#init_column}
    def init_column(name, default, *args)
      if default =~ /NULL/
        @default = nil
      else
        super
      end
    end

    # @override {ActiveRecord::ConnectionAdapters::JdbcColumn#default_value}
    def default_value(value)
      # JDBC returns column default strings with actual single quotes :
      return $1 if value =~ /^'(.*)'$/

      value
    end

    # @override {ActiveRecord::ConnectionAdapters::Column#type_cast}
    def type_cast(value)
      return nil if value.nil?
      case type
        when :string then value
        when :primary_key
          value.respond_to?(:to_i) ? value.to_i : ( value ? 1 : 0 )
        when :float    then value.to_f
        when :decimal  then self.class.value_to_decimal(value)
        when :boolean  then self.class.value_to_boolean(value)
        else super
      end
    end

    private

    # @override {ActiveRecord::ConnectionAdapters::Column#extract_limit}
    def extract_limit(sql_type)
      return nil if sql_type =~ /^(real)\(\d+/i
      super
    end

    def extract_precision(sql_type)
      case sql_type
        when /^(real)\((\d+)(,\d+)?\)/i then $2.to_i
        else super
      end
    end

    def extract_scale(sql_type)
      case sql_type
        when /^(real)\((\d+)\)/i then 0
        when /^(real)\((\d+)(,(\d+))\)/i then $4.to_i
        else super
      end
    end
  end

  remove_const(:SQLite3Adapter) if const_defined?(:SQLite3Adapter)

  # Currently our adapter is named the same as what AR5 names its adapter.  We will need to get
  # this changed at some point so this can be a unique name and we can extend activerecord
  # ActiveRecord::ConnectionAdapters::SQLite3Adapter.  Once we can do that we can remove the
  # module SQLite3 above and remove a majority of this file.
  class SQLite3Adapter < AbstractAdapter
    include ArJdbc::Abstract::Core
    include ArJdbc::SQLite3
    include ArJdbc::Abstract::ConnectionManagement
    include ArJdbc::Abstract::DatabaseStatements
    include ArJdbc::Abstract::StatementCache
    include ArJdbc::Abstract::TransactionSupport

    def self.represent_boolean_as_integer=(value) # :nodoc:
      if value == false
        raise "`.represent_boolean_as_integer=` is now always true, so make sure your application can work with it and remove this settings."
      end

      ActiveSupport::Deprecation.warn(
        "`.represent_boolean_as_integer=` is now always true, so setting this is deprecated and will be removed in Rails 6.1."
      )
    end

    def self.database_exists?(config)
      config = config.symbolize_keys
      if config[:database] == ":memory:"
        return true
      else
        database_file = defined?(Rails.root) ? File.expand_path(config[:database], Rails.root) : config[:database]
        File.exist?(database_file)
      end
    end


    def supports_transaction_isolation?
      false
    end

    def begin_isolated_db_transaction(isolation)
      raise ActiveRecord::TransactionIsolationError, "SQLite3 only supports the `read_uncommitted` transaction isolation level" if isolation != :read_uncommitted
      raise StandardError, "You need to enable the shared-cache mode in SQLite mode before attempting to change the transaction isolation level" unless shared_cache?
      super
    end

    # SQLite driver doesn't support all types of insert statements with executeUpdate so
    # make it act like a regular query and the ids will be returned from #last_inserted_id
    # example: INSERT INTO "aircraft" DEFAULT VALUES
    def exec_insert(sql, name = nil, binds = [], pk = nil, sequence_name = nil)
      exec_query(sql, name, binds)
    end

    def jdbc_column_class
      ::ActiveRecord::ConnectionAdapters::SQLite3Column
    end

    def jdbc_connection_class(spec)
      self.class.jdbc_connection_class
    end

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#jdbc_connection_class
    def self.jdbc_connection_class
      ::ActiveRecord::ConnectionAdapters::SQLite3JdbcConnection
    end

    # Note: This is not an override of ours but a moved line from AR Sqlite3Adapter to register ours vs our copied module (which would be their class).
#    ActiveSupport.run_load_hooks(:active_record_sqlite3adapter, SQLite3Adapter)

    private

    # because the JDBC driver doesn't like multiple SQL statements in one JDBC statement
    def combine_multi_statements(total_sql)
      if total_sql.length == 1
        total_sql.first
      else
        total_sql
      end
    end

    def initialize_type_map(m = type_map)
      super
      register_class_with_limit m, %r(int)i, SQLite3Integer
    end

    # DIFFERENCE: FQN
    class SQLite3Integer < ::ActiveRecord::Type::Integer # :nodoc:
      private
      def _limit
        # INTEGER storage class can be stored 8 bytes value.
        # See https://www.sqlite.org/datatype3.html#storage_classes_and_datatypes
        limit || 8
      end
    end

    # DIFFERENCE: FQN
    ::ActiveRecord::Type.register(:integer, SQLite3Integer, adapter: :sqlite3)
  end
end

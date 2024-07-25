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
require "active_record/connection_adapters/sqlite3/database_statements"
require "active_record/connection_adapters/sqlite3/schema_creation"
require "active_record/connection_adapters/sqlite3/schema_definitions"
require "active_record/connection_adapters/sqlite3/schema_dumper"
require "active_record/connection_adapters/sqlite3/schema_statements"
require "active_support/core_ext/class/attribute"
require "arjdbc/sqlite3/column"

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
    include ::ActiveRecord::ConnectionAdapters::SQLite3::DatabaseStatements

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
    
    class StatementPool < ConnectionAdapters::StatementPool # :nodoc:
      private
      def dealloc(stmt)
        stmt.close unless stmt.closed?
      end
    end

    def self.database_exists?(config)
      @config[:database] == ":memory:" || File.exist?(@config[:database].to_s)
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
      true
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

    def supports_insert_returning?
      database_version >= "3.35.0"
    end

    def supports_insert_on_conflict?
      database_version >= "3.24.0"
    end
    alias supports_insert_on_duplicate_skip? supports_insert_on_conflict?
    alias supports_insert_on_duplicate_update? supports_insert_on_conflict?
    alias supports_insert_conflict_target? supports_insert_on_conflict?

    # DIFFERENCE: active?, reconnect!, disconnect! handles by arjdbc core
    def supports_concurrent_connections?
      !@memory_database
    end

    def active?
      @raw_connection && !@raw_connection.closed?
    end

    def return_value_after_insert?(column) # :nodoc:
      column.auto_populated?
    end

    # MISSING:       alias :reset! :reconnect!

    # Disconnects from the database if already connected. Otherwise, this
    # method does nothing.
    def disconnect!
      super

      @raw_connection&.close rescue nil
      @raw_connection = nil
    end

    def supports_index_sort_order?
      true
    end

    def native_database_types #:nodoc:
      NATIVE_DATABASE_TYPES
    end

    # Returns the current database encoding format as a string, eg: 'UTF-8'
    def encoding
      any_raw_connection.encoding.to_s
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

    def check_all_foreign_keys_valid! # :nodoc:
      sql = "PRAGMA foreign_key_check"
      result = execute(sql)

      unless result.blank?
        tables = result.map { |row| row["table"] }
        raise ActiveRecord::StatementInvalid.new("Foreign key violations found: #{tables.join(", ")}", sql: sql)
      end
    end

    # SCHEMA STATEMENTS ========================================

    def primary_keys(table_name) # :nodoc:
      pks = table_structure(table_name).select { |f| f["pk"] > 0 }
      pks.sort_by { |f| f["pk"] }.map { |f| f["name"] }
    end

    def remove_index(table_name, column_name = nil, **options) # :nodoc:
      return if options[:if_exists] && !index_exists?(table_name, column_name, **options)

      index_name = index_name_for_remove(table_name, column_name, options)

      internal_exec_query "DROP INDEX #{quote_column_name(index_name)}"
    end

    
    # Renames a table.
    #
    # Example:
    #   rename_table('octopuses', 'octopi')
    def rename_table(table_name, new_name, **options)
      validate_table_length!(new_name) unless options[:_uses_legacy_table_name]      
      schema_cache.clear_data_source_cache!(table_name.to_s)
      schema_cache.clear_data_source_cache!(new_name.to_s)
      internal_exec_query "ALTER TABLE #{quote_table_name(table_name)} RENAME TO #{quote_table_name(new_name)}"
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
        definition.foreign_keys.delete_if { |fk| fk.column == column_name.to_s }
      end
    end

    def remove_columns(table_name, *column_names, type: nil, **options) # :nodoc:
      alter_table(table_name) do |definition|
        column_names.each do |column_name|
          definition.remove_column column_name
        end
        column_names = column_names.map(&:to_s)
        definition.foreign_keys.delete_if { |fk| column_names.include?(fk.column) }
      end
    end

    def change_column_default(table_name, column_name, default_or_changes) #:nodoc:
      default = extract_new_default_value(default_or_changes)

      alter_table(table_name) do |definition|
        definition[column_name].default = default
      end
    end

    def change_column_null(table_name, column_name, null, default = nil) #:nodoc:
      validate_change_column_null_argument!(null)

      unless null || default.nil?
        internal_exec_query("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
      end
      alter_table(table_name) do |definition|
        definition[column_name].null = null
      end
    end

    def change_column(table_name, column_name, type, **options) #:nodoc:
      alter_table(table_name) do |definition|
        definition.change_column(column_name, type, **options)
      end
    end

    def rename_column(table_name, column_name, new_column_name) #:nodoc:
      column = column_for(table_name, column_name)
      alter_table(table_name, rename: { column.name => new_column_name.to_s })
      rename_column_indexes(table_name, column.name, new_column_name)
    end

    def add_timestamps(table_name, **options)
      options[:null] = false if options[:null].nil?

      if !options.key?(:precision)
        options[:precision] = 6
      end

      alter_table(table_name) do |definition|
        definition.column :created_at, :datetime, **options
        definition.column :updated_at, :datetime, **options
      end
    end

    def add_reference(table_name, ref_name, **options) # :nodoc:
      super(table_name, ref_name, type: :integer, **options)
    end
    alias :add_belongs_to :add_reference

    def foreign_keys(table_name)
      # SQLite returns 1 row for each column of composite foreign keys.
      fk_info = internal_exec_query("PRAGMA foreign_key_list(#{quote(table_name)})", "SCHEMA")
      grouped_fk = fk_info.group_by { |row| row["id"] }.values.each { |group| group.sort_by! { |row| row["seq"] } }
      grouped_fk.map do |group|
        row = group.first
        options = {
          on_delete: extract_foreign_key_action(row["on_delete"]),
          on_update: extract_foreign_key_action(row["on_update"])
        }

        if group.one?
          options[:column] = row["from"]
          options[:primary_key] = row["to"]
        else
          options[:column] = group.map { |row| row["from"] }
          options[:primary_key] = group.map { |row| row["to"] }
        end
        # DIFFERENCE: FQN
        ::ActiveRecord::ConnectionAdapters::ForeignKeyDefinition.new(table_name, row["table"], options)
      end
    end

    def build_insert_sql(insert) # :nodoc:
      sql = +"INSERT #{insert.into} #{insert.values_list}"

      if insert.skip_duplicates?
        sql << " ON CONFLICT #{insert.conflict_target} DO NOTHING"
      elsif insert.update_duplicates?
        sql << " ON CONFLICT #{insert.conflict_target} DO UPDATE SET "
        if insert.raw_update_sql?
          sql << insert.raw_update_sql
        else
          sql << insert.touch_model_timestamps_unless { |column| "#{column} IS excluded.#{column}" }
          sql << insert.updatable_columns.map { |column| "#{column}=excluded.#{column}" }.join(",")
        end
      end

      sql << " RETURNING #{insert.returning}" if insert.returning
      sql
    end

    def shared_cache? # :nodoc:
      @config.fetch(:flags, 0).anybits?(::SQLite3::Constants::Open::SHAREDCACHE)
    end

    def use_insert_returning?
      @use_insert_returning
    end

    def get_database_version # :nodoc:
      SQLite3Adapter::Version.new(query_value("SELECT sqlite_version(*)", "SCHEMA"))
    end

    def check_version
      if database_version < "3.8.0"
        raise "Your version of SQLite (#{database_version}) is too old. Active Record supports SQLite >= 3.8."
      end
    end

    # DIFFERENCE: here to 
    def new_column_from_field(table_name, field, definitions)
      default = field["dflt_value"]

      type_metadata = fetch_type_metadata(field["type"])
      default_value = extract_value_from_default(default)
      default_function = extract_default_function(default_value, default)
      rowid = is_column_the_rowid?(field, definitions)

      ActiveRecord::ConnectionAdapters::SQLite3Column.new(
        field["name"],
        default_value,
        type_metadata,
        field["notnull"].to_i == 0,
        default_function,
        collation: field["collation"],
        auto_increment: field["auto_increment"],
        rowid: rowid
      )
    end

    private
    # See https://www.sqlite.org/limits.html,
    # the default value is 999 when not configured.
    def bind_params_length
      999
    end

    def table_structure(table_name)
      structure = internal_exec_query("PRAGMA table_info(#{quote_table_name(table_name)})", "SCHEMA")
      raise(ActiveRecord::StatementInvalid, "Could not find table '#{table_name}'") if structure.empty?
      table_structure_with_collation(table_name, structure)
    end
    alias column_definitions table_structure

    def extract_value_from_default(default)
      case default
      when /^null$/i
        nil
      # Quoted types
      when /^'([^|]*)'$/m
        $1.gsub("''", "'")
      # Quoted types
      when /^"([^|]*)"$/m
        $1.gsub('""', '"')
      # Numeric types
      when /\A-?\d+(\.\d*)?\z/
        $&
      # Binary columns
      when /x'(.*)'/
        [ $1 ].pack("H*")
      else
        # Anything else is blank or some function
        # and we can't know the value of that, so return nil.
        nil
      end
    end

    def extract_default_function(default_value, default)
      default if has_default_function?(default_value, default)
    end

    def has_default_function?(default_value, default)
      !default_value && %r{\w+\(.*\)|CURRENT_TIME|CURRENT_DATE|CURRENT_TIMESTAMP|\|\|}.match?(default)
    end

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

          if column.has_default?
            type = lookup_cast_type_from_column(column)
            default = type.deserialize(column.default)
            default = -> { column.default_function } if default.nil?
          end

          column_options = {
            limit: column.limit,
            precision: column.precision,
            scale: column.scale,
            null: column.null,
            collation: column.collation,
            primary_key: column_name == from_primary_key
          }

          unless column.auto_increment?
            column_options[:default] = default
          end

          column_type = column.bigint? ? :bigint : column.type
          @definition.column(column_name, column_type, **column_options)
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
          options[:order] = index.orders if index.orders
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

      internal_exec_query("INSERT INTO #{quote_table_name(to)} (#{quoted_columns})
                            SELECT #{quoted_from_columns} FROM #{quote_table_name(from)}")
    end

    def translate_exception(exception, message:, sql:, binds:)
      # SQLite 3.8.2 returns a newly formatted error message:
      #   UNIQUE constraint failed: *table_name*.*column_name*
      # Older versions of SQLite return:
      #   column *column_name* is not unique
      if exception.message.match?(/(column(s)? .* (is|are) not unique|UNIQUE constraint failed: .*)/i)
        # DIFFERENCE: FQN
        ::ActiveRecord::RecordNotUnique.new(message, sql: sql, binds: binds, connection_pool: @pool)
      elsif exception.message.match?(/(.* may not be NULL|NOT NULL constraint failed: .*)/i)
        # DIFFERENCE: FQN
        ::ActiveRecord::NotNullViolation.new(message, sql: sql, binds: binds, connection_pool: @pool)
      elsif exception.message.match?(/FOREIGN KEY constraint failed/i)
        # DIFFERENCE: FQN
        ::ActiveRecord::InvalidForeignKey.new(message, sql: sql, binds: binds, connection_pool: @pool)
      elsif exception.message.match?(/called on a closed database/i)
        # DIFFERENCE: FQN
        ::ActiveRecord::ConnectionNotEstablished.new(exception, connection_pool: @pool)
      elsif exception.message.match?(/sql error/i)
        ::ActiveRecord::StatementInvalid.new(message, sql: sql, binds: binds, connection_pool: @pool)
      elsif exception.message.match?(/write a readonly database/i)
        message = message.sub('org.sqlite.SQLiteException', 'SQLite3::ReadOnlyException')
        ::ActiveRecord::StatementInvalid.new(message, sql: sql, binds: binds, connection_pool: @pool)
      else
        super
      end
    end

    COLLATE_REGEX = /.*\"(\w+)\".*collate\s+\"(\w+)\".*/i.freeze
    PRIMARY_KEY_AUTOINCREMENT_REGEX = /.*\"(\w+)\".+PRIMARY KEY AUTOINCREMENT/i

    def table_structure_with_collation(table_name, basic_structure)
      collation_hash = {}
      auto_increments = {}
      sql = <<~SQL
        SELECT sql FROM
          (SELECT * FROM sqlite_master UNION ALL
           SELECT * FROM sqlite_temp_master)
        WHERE type = 'table' AND name = #{quote(table_name)}
      SQL

      # Result will have following sample string
      # CREATE TABLE "users" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
      #                       "password_digest" varchar COLLATE "NOCASE");
      result = query_value(sql, "SCHEMA")

      if result
        # Splitting with left parentheses and discarding the first part will return all
        # columns separated with comma(,).
        columns_string = result.split("(", 2).last

        columns_string.split(",").each do |column_string|
          # This regex will match the column name and collation type and will save
          # the value in $1 and $2 respectively.
          collation_hash[$1] = $2 if COLLATE_REGEX =~ column_string
          auto_increments[$1] = true if PRIMARY_KEY_AUTOINCREMENT_REGEX =~ column_string
        end

        basic_structure.map do |column|
          column_name = column["name"]

          if collation_hash.has_key? column_name
            column["collation"] = collation_hash[column_name]
          end

          if auto_increments.has_key?(column_name)
            column["auto_increment"] = true
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

    def build_statement_pool
      StatementPool.new(self.class.type_cast_config_to_integer(@config[:statement_limit]))
    end

    def configure_connection
      if @config[:timeout] && @config[:retries]
        raise ArgumentError, "Cannot specify both timeout and retries arguments"
      elsif @config[:timeout]
        # FIXME: missing from adapter
        # @raw_connection.busy_timeout(self.class.type_cast_config_to_integer(@config[:timeout]))
      elsif @config[:retries]
        retries = self.class.type_cast_config_to_integer(@config[:retries])
        raw_connection.busy_handler do |count|
          count <= retries
        end
      end

      # Enforce foreign key constraints
      # https://www.sqlite.org/pragma.html#pragma_foreign_keys
      # https://www.sqlite.org/foreignkeys.html
      raw_execute("PRAGMA foreign_keys = ON", "SCHEMA")
      unless @memory_database
        # Journal mode WAL allows for greater concurrency (many readers + one writer)
        # https://www.sqlite.org/pragma.html#pragma_journal_mode
        raw_execute("PRAGMA journal_mode = WAL", "SCHEMA")
        # Set more relaxed level of database durability
        # 2 = "FULL" (sync on every write), 1 = "NORMAL" (sync every 1000 written pages) and 0 = "NONE"
        # https://www.sqlite.org/pragma.html#pragma_synchronous
        raw_execute("PRAGMA synchronous = NORMAL", "SCHEMA")
        # Set the global memory map so all processes can share some data
        # https://www.sqlite.org/pragma.html#pragma_mmap_size
        # https://www.sqlite.org/mmap.html
        raw_execute("PRAGMA mmap_size = #{128.megabytes}", "SCHEMA")
      end
      # Impose a limit on the WAL file to prevent unlimited growth
      # https://www.sqlite.org/pragma.html#pragma_journal_size_limit
      raw_execute("PRAGMA journal_size_limit = #{64.megabytes}", "SCHEMA")
      # Set the local connection cache to 2000 pages
      # https://www.sqlite.org/pragma.html#pragma_cache_size
      raw_execute("PRAGMA cache_size = 2000", "SCHEMA")
    end

    def configure_connection
      if @config[:timeout] && @config[:retries]
        raise ArgumentError, "Cannot specify both timeout and retries arguments"
      elsif @config[:timeout]
        # FIXME:
#        @raw_connection.busy_timeout(self.class.type_cast_config_to_integer(@config[:timeout]))
      elsif @config[:retries]
        retries = self.class.type_cast_config_to_integer(@config[:retries])
        raw_connection.busy_handler do |count|
          count <= retries
        end
      end

      # Enforce foreign key constraints
      # https://www.sqlite.org/pragma.html#pragma_foreign_keys
      # https://www.sqlite.org/foreignkeys.html
      raw_execute("PRAGMA foreign_keys = ON", "SCHEMA")
      unless @memory_database
        # Journal mode WAL allows for greater concurrency (many readers + one writer)
        # https://www.sqlite.org/pragma.html#pragma_journal_mode
        raw_execute("PRAGMA journal_mode = WAL", "SCHEMA")
        # Set more relaxed level of database durability
        # 2 = "FULL" (sync on every write), 1 = "NORMAL" (sync every 1000 written pages) and 0 = "NONE"
        # https://www.sqlite.org/pragma.html#pragma_synchronous
        raw_execute("PRAGMA synchronous = NORMAL", "SCHEMA")
        # Set the global memory map so all processes can share some data
        # https://www.sqlite.org/pragma.html#pragma_mmap_size
        # https://www.sqlite.org/mmap.html
        raw_execute("PRAGMA mmap_size = #{128.megabytes}", "SCHEMA")
      end
      # Impose a limit on the WAL file to prevent unlimited growth
      # https://www.sqlite.org/pragma.html#pragma_journal_size_limit
      raw_execute("PRAGMA journal_size_limit = #{64.megabytes}", "SCHEMA")
      # Set the local connection cache to 2000 pages
      # https://www.sqlite.org/pragma.html#pragma_cache_size
      raw_execute("PRAGMA cache_size = 2000", "SCHEMA")      
    end
  end
  # DIFFERENCE: A registration here is moved down to concrete class so we are not registering part of an adapter.
end

module ActiveRecord::ConnectionAdapters

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

    ##
    # :singleton-method:
    # Configure the SQLite3Adapter to be used in a strict strings mode.
    # This will disable double-quoted string literals, because otherwise typos can silently go unnoticed.
    # For example, it is possible to create an index for a non existing column.
    # If you wish to enable this mode you can add the following line to your application.rb file:
    #
    #   config.active_record.sqlite3_adapter_strict_strings_by_default = true
    class_attribute :strict_strings_by_default, default: false # Does not actually do anything right now

    def initialize(...)
      super

      conn_params = @config.compact

      @connection_parameters = conn_params
    end

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
    def exec_insert(sql, name = nil, binds = [], pk = nil, sequence_name = nil, returning: nil)
      sql, binds = sql_for_insert(sql, pk, binds, returning)
      internal_exec_query(sql, name, binds)
    end

    def jdbc_column_class
      ::ActiveRecord::ConnectionAdapters::SQLite3Column
    end

    # Note: This is not an override of ours but a moved line from AR Sqlite3Adapter to register ours vs our copied module (which would be their class).
#    ActiveSupport.run_load_hooks(:active_record_sqlite3adapter, SQLite3Adapter)

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

    class << self
      def jdbc_connection_class
        ::ActiveRecord::ConnectionAdapters::SQLite3JdbcConnection
      end

      def new_client(conn_params, adapter_instance)
        jdbc_connection_class.new(conn_params, adapter_instance)
      end

      def dbconsole(config, options = {})
        args = []

        args << "-#{options[:mode]}" if options[:mode]
        args << "-header" if options[:header]
        args << File.expand_path(config.database, const_defined?(:Rails) && Rails.respond_to?(:root) ? Rails.root : nil)

        find_cmd_and_exec("sqlite3", *args)
      end

      private
        def initialize_type_map(m)
          super
          register_class_with_limit m, %r(int)i, SQLite3Integer
        end
    end

    TYPE_MAP = ActiveRecord::Type::TypeMap.new.tap { |m| initialize_type_map(m) }

    private

    # because the JDBC driver doesn't like multiple SQL statements in one JDBC statement
    def combine_multi_statements(total_sql)
      total_sql
    end

    def type_map
      TYPE_MAP
    end

    # combine
    def write_query?(sql) # :nodoc:
      return sql.any? { |stmt| super(stmt) } if sql.kind_of? Array
      !READ_QUERY.match?(sql)
    rescue ArgumentError # Invalid encoding
      !READ_QUERY.match?(sql.b)
    end
  end
end

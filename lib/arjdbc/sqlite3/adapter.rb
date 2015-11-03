ArJdbc.load_java_part :SQLite3

require 'arjdbc/sqlite3/explain_support'
require 'arjdbc/util/table_copier'

module ArJdbc
  module SQLite3
    include Util::TableCopier

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#jdbc_connection_class
    def self.jdbc_connection_class
      ::ActiveRecord::ConnectionAdapters::SQLite3JdbcConnection
    end

    def jdbc_column_class; ::ActiveRecord::ConnectionAdapters::SQLite3Column end

    # @see ActiveRecord::ConnectionAdapters::JdbcColumn#column_types
    def self.column_selector
      [ /sqlite/i, lambda { |config, column| column.extend(Column) } ]
    end

    # @see ActiveRecord::ConnectionAdapters::JdbcColumn
    module Column

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

      # @override {ActiveRecord::ConnectionAdapters::Column#simplified_type}
      def simplified_type(field_type)
        case field_type
        when /boolean/i       then :boolean
        when /text/i          then :text
        when /varchar/i       then :string
        when /int/i           then :integer
        when /float/i         then :float
        when /real|decimal/i  then
          extract_scale(field_type) == 0 ? :integer : :decimal
        when /datetime/i      then :datetime
        when /date/i          then :date
        when /time/i          then :time
        when /blob/i          then :binary
        else super
        end
      end

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

    # @see ActiveRecord::ConnectionAdapters::Jdbc::ArelSupport
    def self.arel_visitor_type(config = nil)
      ::Arel::Visitors::SQLite
    end

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#bind_substitution
    # @private
    class BindSubstitution < ::Arel::Visitors::SQLite
      include ::Arel::Visitors::BindVisitor
    end if defined? ::Arel::Visitors::BindVisitor

    ADAPTER_NAME = 'SQLite'.freeze

    def adapter_name
      ADAPTER_NAME
    end

    NATIVE_DATABASE_TYPES = {
      :primary_key => nil,
      :string => { :name => "varchar", :limit => 255 },
      :text => { :name => "text" },
      :integer => { :name => "integer" },
      :float => { :name => "float" },
      # :real => { :name=>"real" },
      :decimal => { :name => "decimal" },
      :datetime => { :name => "datetime" },
      :timestamp => { :name => "datetime" },
      :time => { :name => "time" },
      :date => { :name => "date" },
      :binary => { :name => "blob" },
      :boolean => { :name => "boolean" }
    }
    NATIVE_DATABASE_TYPES.update(
      :string => { :name => "varchar" }
    ) if AR42

    # @override
    def native_database_types
      types = NATIVE_DATABASE_TYPES.dup
      types[:primary_key] = default_primary_key_type
      types
    end

    def default_primary_key_type
      if supports_autoincrement?
        'integer PRIMARY KEY AUTOINCREMENT NOT NULL'
      else
        'integer PRIMARY KEY NOT NULL'
      end
    end

    # @override
    def supports_ddl_transactions?
      true
    end

    # @override
    def supports_savepoints?
      sqlite_version >= '3.6.8'
    end

    # @override
    def supports_partial_index?
      sqlite_version >= '3.8.0'
    end

    # @override
    def supports_add_column?
      true
    end

    # @override
    def supports_count_distinct?
      true
    end

    # @override
    def supports_autoincrement?
      true
    end

    # @override
    def supports_migrations?
      true
    end

    # @override
    def supports_primary_key?
      true
    end

    # @override
    def supports_add_column?
      true
    end

    # @override
    def supports_count_distinct?
      true
    end

    # @override
    def supports_autoincrement?
      true
    end

    # @override
    def supports_index_sort_order?
      true
    end

    # @override
    def supports_views?
      true
    end

    def sqlite_version
      @sqlite_version ||= Version.new(select_value('SELECT sqlite_version(*)'))
    end
    private :sqlite_version

    # @override
    def quote(value, column = nil)
      return value if sql_literal?(value)

      if value.kind_of?(String)
        column_type = column && column.type
        if column_type == :binary
          "x'#{value.unpack("H*")[0]}'"
        else
          super
        end
      else
        super
      end
    end

    def quote_table_name_for_assignment(table, attr)
      quote_column_name(attr)
    end if ::ActiveRecord::VERSION::MAJOR >= 4

    # @override
    def quote_column_name(name)
      %Q("#{name.to_s.gsub('"', '""')}") # "' kludge for emacs font-lock
    end

    # Quote date/time values for use in SQL input.
    # Includes microseconds if the value is a Time responding to usec.
    # @override
    def quoted_date(value)
      if value.acts_like?(:time) && value.respond_to?(:usec)
        "#{super}.#{sprintf("%06d", value.usec)}"
      else
        super
      end
    end if ::ActiveRecord::VERSION::MAJOR >= 3

    # @override
    def tables(name = nil, table_name = nil)
      sql = "SELECT name FROM sqlite_master WHERE type = 'table'"
      if table_name
        sql << " AND name = #{quote_table_name(table_name)}"
      else
        sql << " AND NOT name = 'sqlite_sequence'"
      end

      select_rows(sql, name).map { |row| row[0] }
    end

    # @override
    def table_exists?(table_name)
      table_name && tables(nil, table_name).any?
    end

    def truncate_fake(table_name, name = nil)
      execute "DELETE FROM #{quote_table_name(table_name)}; VACUUM", name
    end
    # NOTE: not part of official AR (4.2) alias truncate truncate_fake

    # Returns 62. SQLite supports index names up to 64 characters.
    # The rest is used by Rails internally to perform temporary rename operations.
    # @return [Fixnum]
    def allowed_index_name_length
      index_name_length - 2
    end

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

    # @private
    def recreate_database(name = nil, options = {})
      drop_database(name)
      create_database(name, options)
    end

    # @private
    def create_database(name = nil, options = {})
    end

    # @private
    def drop_database(name = nil)
      tables.each { |table| drop_table(table) }
    end

    def select(sql, name = nil, binds = [])
      result = super # AR::Result (4.0) or Array (<= 3.2)
      if result.respond_to?(:columns) # 4.0
        result.columns.map! do |key| # [ [ 'id', ... ]
          key.is_a?(String) ? key.sub(/^"?\w+"?\./, '') : key
        end
      else
        result.map! do |row| # [ { 'id' => ... }, {...} ]
          record = {}
          row.each_key do |key|
            if key.is_a?(String)
              record[key.sub(/^"?\w+"?\./, '')] = row[key]
            end
          end
          record
        end
      end
      result
    end

    # @note We have an extra binds argument at the end due AR-2.3 support.
    # @override
    def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [])
      result = execute(sql, name, binds)
      id_value || last_inserted_id(result)
    end

    # @note Does not support prepared statements for INSERT statements.
    # @override
    def exec_insert(sql, name, binds, pk = nil, sequence_name = nil)
      # NOTE: since SQLite JDBC does not support executeUpdate but only
      # statement.execute we can not support prepared statements here :
      execute(sql, name, binds)
    end

    def table_structure(table_name)
      sql = "PRAGMA table_info(#{quote_table_name(table_name)})"
      log(sql, 'SCHEMA') { @connection.execute_query_raw(sql) }
    rescue ActiveRecord::JDBCError => error
      e = ActiveRecord::StatementInvalid.new("Could not find table '#{table_name}'")
      e.set_backtrace error.backtrace
      raise e
    end

    # @override
    def columns(table_name, name = nil)
      column = jdbc_column_class
      pass_cast_type = respond_to?(:lookup_cast_type)
      table_structure(table_name).map do |field|
        sql_type = field['type']
        if pass_cast_type
          cast_type = lookup_cast_type(sql_type)
          column.new(field['name'], field['dflt_value'], cast_type, sql_type, field['notnull'] == 0)
        else
          column.new(field['name'], field['dflt_value'], sql_type, field['notnull'] == 0)
        end
      end
    end

    # @override
    def primary_key(table_name)
      column = table_structure(table_name).find { |field| field['pk'].to_i == 1 }
      column && column['name']
    end

    # NOTE: do not override indexes without testing support for 3.7.2 & 3.8.7 !
    # @override
    def indexes(table_name, name = nil)
      # on JDBC 3.7 we'll simply do super since it can not handle "PRAGMA index_info"
      return @connection.indexes(table_name, name) if sqlite_version < '3.8' # super

      name ||= 'SCHEMA'
      exec_query_raw("PRAGMA index_list(#{quote_table_name(table_name)})", name).map do |row|
        index_name = row['name']
        sql = "SELECT sql FROM sqlite_master"
        sql << " WHERE name=#{quote(index_name)} AND type='index'"
        sql << " UNION ALL "
        sql << "SELECT sql FROM sqlite_temp_master"
        sql << " WHERE name=#{quote(index_name)} AND type='index'"
        where = nil
        exec_query_raw(sql, name) do |index_sql|
          match = /\sWHERE\s+(.+)$/i.match(index_sql)
          where = match[1] if match
        end
        begin
          columns = exec_query_raw("PRAGMA index_info('#{index_name}')", name).map { |col| col['name'] }
        rescue => e
          # NOTE: JDBC <= 3.8.7 bug work-around :
          if e.message && e.message.index('[SQLITE_ERROR] SQL error or missing database')
            columns = []
          end
          raise e
        end
        new_index_definition(table_name, index_name, row['unique'] != 0, columns, nil, nil, where)
      end
    end

    # @override
    def remove_index!(table_name, index_name)
      execute "DROP INDEX #{quote_column_name(index_name)}"
    end

    # @override
    def rename_table(table_name, new_name)
      execute "ALTER TABLE #{quote_table_name(table_name)} RENAME TO #{quote_table_name(new_name)}"
      rename_table_indexes(table_name, new_name) if respond_to?(:rename_table_indexes) # AR-4.0 SchemaStatements
    end

    # SQLite has an additional restriction on the ALTER TABLE statement.
    # @see http://www.sqlite.org/lang_altertable.html
    def valid_alter_table_options( type, options)
      type.to_sym != :primary_key
    end

    def add_column(table_name, column_name, type, options = {})
      if supports_add_column? && valid_alter_table_options( type, options )
        super(table_name, column_name, type, options)
      else
        alter_table(table_name) do |definition|
          definition.column(column_name, type, options)
        end
      end
    end

    if ActiveRecord::VERSION::MAJOR >= 4

    # @private
    def remove_column(table_name, column_name, type = nil, options = {})
      alter_table(table_name) do |definition|
        definition.remove_column column_name
      end
    end

    else

    # @private
    def remove_column(table_name, *column_names)
      if column_names.empty?
        raise ArgumentError.new(
          "You must specify at least one column name." +
          "  Example: remove_column(:people, :first_name)"
        )
      end
      column_names.flatten.each do |column_name|
        alter_table(table_name) do |definition|
          definition.columns.delete(definition[column_name])
        end
      end
    end
    alias :remove_columns :remove_column

    end

    def change_column_default(table_name, column_name, default) #:nodoc:
      alter_table(table_name) do |definition|
        definition[column_name].default = default
      end
    end

    def change_column_null(table_name, column_name, null, default = nil)
      unless null || default.nil?
        execute("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
      end
      alter_table(table_name) do |definition|
        definition[column_name].null = null
      end
    end

    def change_column(table_name, column_name, type, options = {})
      alter_table(table_name) do |definition|
        include_default = options_include_default?(options)
        definition[column_name].instance_eval do
          self.type    = type
          self.limit   = options[:limit] if options.include?(:limit)
          self.default = options[:default] if include_default
          self.null    = options[:null] if options.include?(:null)
          self.precision = options[:precision] if options.include?(:precision)
          self.scale   = options[:scale] if options.include?(:scale)
        end
      end
    end

    def rename_column(table_name, column_name, new_column_name)
      unless columns(table_name).detect{|c| c.name == column_name.to_s }
        raise ActiveRecord::ActiveRecordError, "Missing column #{table_name}.#{column_name}"
      end
      alter_table(table_name, :rename => {column_name.to_s => new_column_name.to_s})
      rename_column_indexes(table_name, column_name, new_column_name) if respond_to?(:rename_column_indexes) # AR-4.0 SchemaStatements
    end

    # @private
    def add_lock!(sql, options)
      sql # SELECT ... FOR UPDATE is redundant since the table is locked
    end if ::ActiveRecord::VERSION::MAJOR < 3

    def empty_insert_statement_value
      # inherited (default) on 3.2 : "VALUES(DEFAULT)"
      # inherited (default) on 4.0 : "DEFAULT VALUES"
      # re-defined in native adapter on 3.2 "VALUES(NULL)"
      # on 4.0 no longer re-defined (thus inherits default)
      "DEFAULT VALUES"
    end

    def encoding
      select_value 'PRAGMA encoding'
    end

    def last_insert_id
      @connection.last_insert_rowid
    end

    protected

    def last_inserted_id(result)
      super || last_insert_id # NOTE: #last_insert_id call should not be needed
    end

    def translate_exception(exception, message)
      if msg = exception.message
        # SQLite 3.8.2 returns a newly formatted error message:
        #   UNIQUE constraint failed: *table_name*.*column_name*
        # Older versions of SQLite return:
        #   column *column_name* is not unique
        if msg.index('UNIQUE constraint failed: ') ||
           msg =~ /column(s)? .* (is|are) not unique/
          return ::ActiveRecord::RecordNotUnique.new(message, exception)
        end
      end
      super
    end

    # @private available in native adapter way back to AR-2.3
    class Version
      include Comparable

      def initialize(version_string)
        @version = version_string.split('.').map! { |v| v.to_i }
      end

      def <=>(version_string)
        @version <=> version_string.split('.').map! { |v| v.to_i }
      end

      def to_s
        @version.join('.')
      end

    end

  end
end

module ActiveRecord::ConnectionAdapters

  # NOTE: SQLite3Column exists in native adapter since AR 4.0
  remove_const(:SQLite3Column) if const_defined?(:SQLite3Column)

  class SQLite3Column < JdbcColumn
    include ArJdbc::SQLite3::Column

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
  end

  remove_const(:SQLite3Adapter) if const_defined?(:SQLite3Adapter)

  class SQLite3Adapter < JdbcAdapter
    include ArJdbc::SQLite3
    include ArJdbc::SQLite3::ExplainSupport

    def jdbc_connection_class(spec)
      ::ArJdbc::SQLite3.jdbc_connection_class
    end

    # @private
    Version = ArJdbc::SQLite3::Version

  end

  if ActiveRecord::VERSION::MAJOR <= 3
    remove_const(:SQLiteColumn) if const_defined?(:SQLiteColumn)
    SQLiteColumn = SQLite3Column

    remove_const(:SQLiteAdapter) if const_defined?(:SQLiteAdapter)

    SQLiteAdapter = SQLite3Adapter
  end
end

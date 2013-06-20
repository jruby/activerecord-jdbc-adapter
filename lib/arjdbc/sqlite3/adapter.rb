ArJdbc.load_java_part :SQLite3

require 'arjdbc/jdbc/missing_functionality_helper'
require 'arjdbc/sqlite3/explain_support'

module ArJdbc
  module SQLite3

    def self.column_selector
      [ /sqlite/i, lambda { |cfg,col| col.extend(::ArJdbc::SQLite3::Column) } ]
    end

    def self.jdbc_connection_class
      ::ActiveRecord::ConnectionAdapters::SQLite3JdbcConnection
    end

    module Column

      # #override {JdbcColumn#init_column}
      def init_column(name, default, *args)
        if default =~ /NULL/
          @default = nil
        else
          super
        end
      end

      # #override {ActiveRecord::ConnectionAdapters::Column#type_cast}
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

      # Post process default value from JDBC into a Rails-friendly format (columns{-internal})
      def default_value(value)
        # jdbc returns column default strings with actual single quotes around the value.
        return $1 if value =~ /^'(.*)'$/

        value
      end

    end

    def self.arel2_visitors(config = nil)
      { 'sqlite3' => ::Arel::Visitors::SQLite, 'jdbcsqlite3' => ::Arel::Visitors::SQLite }
    end

    def new_visitor(config = nil)
      visitor = ::Arel::Visitors::SQLite
      ( prepared_statements? ? visitor : bind_substitution(visitor) ).new(self)
    end if defined? ::Arel::Visitors::SQLite

    # @see #bind_substitution
    class BindSubstitution < Arel::Visitors::SQLite # :nodoc:
      include Arel::Visitors::BindVisitor
    end if defined? Arel::Visitors::BindVisitor

    ADAPTER_NAME = 'SQLite'.freeze

    def adapter_name # :nodoc:
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

    def supports_ddl_transactions? # :nodoc:
      true # sqlite_version >= '2.0.0'
    end

    def supports_savepoints? # :nodoc:
      sqlite_version >= '3.6.8'
    end

    def supports_add_column? # :nodoc:
      sqlite_version >= '3.1.6'
    end

    def supports_count_distinct? # :nodoc:
      sqlite_version >= '3.2.6'
    end

    def supports_autoincrement? # :nodoc:
      sqlite_version >= '3.1.0'
    end

    def supports_index_sort_order? # :nodoc:
      sqlite_version >= '3.3.0'
    end

    def supports_migrations? # :nodoc:
      true
    end

    def supports_primary_key? # :nodoc:
      true
    end

    def supports_add_column? # :nodoc:
      true
    end

    def supports_count_distinct? # :nodoc:
      true
    end

    def supports_autoincrement? # :nodoc:
      true
    end

    def supports_index_sort_order? # :nodoc:
      true
    end

    def sqlite_version
      @sqlite_version ||= select_value('SELECT sqlite_version(*)')
    end
    private :sqlite_version

    def quote(value, column = nil)
      if value.kind_of?(String)
        column_type = column && column.type
        if column_type == :binary && column.class.respond_to?(:string_to_binary)
          "x'#{column.class.string_to_binary(value).unpack("H*")[0]}'"
        else
          super
        end
      else
        super
      end
    end

    def quote_table_name_for_assignment(table, attr)
      quote_column_name(attr)
    end if ::ActiveRecord::VERSION::MAJOR > 3

    def quote_column_name(name) # :nodoc:
      %Q("#{name.to_s.gsub('"', '""')}") # "' kludge for emacs font-lock
    end

    # Quote date/time values for use in SQL input. Includes microseconds
    # if the value is a Time responding to usec.
    def quoted_date(value) # :nodoc:
      if value.respond_to?(:usec)
        "#{super}.#{sprintf("%06d", value.usec)}"
      else
        super
      end
    end

    # NOTE: we have an extra binds argument at the end due 2.3 support.
    def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = []) # :nodoc:
      execute(sql, name, binds)
      id_value || last_insert_id
    end

    def tables(name = nil, table_name = nil) # :nodoc:
      sql = "SELECT name FROM sqlite_master WHERE type = 'table'"
      if table_name
        sql << " AND name = #{quote_table_name(table_name)}"
      else
        sql << " AND NOT name = 'sqlite_sequence'"
      end

      select_rows(sql, name).map { |row| row[0] }
    end

    def table_exists?(table_name)
      table_name && tables(nil, table_name).any?
    end

    # Returns 62. SQLite supports index names up to 64
    # characters. The rest is used by rails internally to perform
    # temporary rename operations
    def allowed_index_name_length
      index_name_length - 2
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

    def recreate_database(name = nil, options = {}) # :nodoc:
      drop_database(name)
      create_database(name, options)
    end

    def create_database(name = nil, options = {}) # :nodoc:
    end

    def drop_database(name = nil) # :nodoc:
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

    # @override as <code>execute_insert</code> not implemented by SQLite JDBC
    def exec_insert(sql, name, binds, pk = nil, sequence_name = nil) # :nodoc:
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

    def columns(table_name, name = nil) # :nodoc:
      klass = ::ActiveRecord::ConnectionAdapters::SQLite3Column
      table_structure(table_name).map do |field|
        klass.new(field['name'], field['dflt_value'], field['type'], field['notnull'] == 0)
      end
    end

    def primary_key(table_name) #:nodoc:
      column = table_structure(table_name).find { |field| field['pk'].to_i == 1 }
      column && column['name']
    end

    def remove_index!(table_name, index_name) # :nodoc:
      execute "DROP INDEX #{quote_column_name(index_name)}"
    end

    def rename_table(table_name, new_name)
      execute "ALTER TABLE #{quote_table_name(table_name)} RENAME TO #{quote_table_name(new_name)}"
      rename_table_indexes(table_name, new_name) if respond_to?(:rename_table_indexes) # AR-4.0 SchemaStatements
    end

    # See: http://www.sqlite.org/lang_altertable.html
    # SQLite has an additional restriction on the ALTER TABLE statement
    def valid_alter_table_options( type, options)
      type.to_sym != :primary_key
    end

    def add_column(table_name, column_name, type, options = {}) #:nodoc:
      if supports_add_column? && valid_alter_table_options( type, options )
        super(table_name, column_name, type, options)
      else
        alter_table(table_name) do |definition|
          definition.column(column_name, type, options)
        end
      end
    end

    if ActiveRecord::VERSION::MAJOR >= 4

    def remove_column(table_name, column_name, type = nil, options = {}) #:nodoc:
      alter_table(table_name) do |definition|
        definition.remove_column column_name
      end
    end

    else

    def remove_column(table_name, *column_names) #:nodoc:
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

    def change_column(table_name, column_name, type, options = {}) #:nodoc:
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

    def rename_column(table_name, column_name, new_column_name) #:nodoc:
      unless columns(table_name).detect{|c| c.name == column_name.to_s }
        raise ActiveRecord::ActiveRecordError, "Missing column #{table_name}.#{column_name}"
      end
      alter_table(table_name, :rename => {column_name.to_s => new_column_name.to_s})
      rename_column_indexes(table_name, column_name, new_column_name) if respond_to?(:rename_column_indexes) # AR-4.0 SchemaStatements
    end

     # SELECT ... FOR UPDATE is redundant since the table is locked.
    def add_lock!(sql, options) #:nodoc:
      sql
    end

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

    protected

    include ArJdbc::MissingFunctionalityHelper

    def translate_exception(exception, message)
      case exception.message
      when /column(s)? .* (is|are) not unique/
        ActiveRecord::RecordNotUnique.new(message, exception)
      else
        super
      end
    end

    def last_insert_id
      @connection.last_insert_row_id
    end

    def last_inserted_id(result)
      last_insert_id
    end

    private

    def _execute(sql, name = nil)
      result = super
      self.class.insert?(sql) ? last_insert_id : result
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

    def jdbc_column_class
      ::ActiveRecord::ConnectionAdapters::SQLite3Column
    end

  end

  if ActiveRecord::VERSION::MAJOR <= 3
    remove_const(:SQLiteColumn) if const_defined?(:SQLiteColumn)
    SQLiteColumn = SQLite3Column

    remove_const(:SQLiteAdapter) if const_defined?(:SQLiteAdapter)

    SQLiteAdapter = SQLite3Adapter
  end
end
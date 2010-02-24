module ::JdbcSpec
  # Don't need to load native postgres adapter
  $LOADED_FEATURES << "active_record/connection_adapters/sqlite3_adapter.rb"

  module ActiveRecordExtensions
    add_method_to_remove_from_ar_base(:sqlite3_connection)

    def sqlite3_connection(config)
      require File.dirname(__FILE__) + "/../active_record/connection_adapters/sqlite3_adapter"

      parse_sqlite3_config!(config)

      config[:url] ||= "jdbc:sqlite:#{config[:database]}"
      config[:driver] ||= "org.sqlite.JDBC"
      jdbc_connection(config)
    end

    def parse_sqlite3_config!(config)
      config[:database] ||= config[:dbfile]

      # Allow database path relative to RAILS_ROOT, but only if
      # the database path is not the special path that tells
      # Sqlite to build a database only in memory.
      rails_root_defined = defined?(Rails.root) || Object.const_defined?(:RAILS_ROOT)
      if rails_root_defined && ':memory:' != config[:database]
        rails_root = defined?(Rails.root) ? Rails.root : RAILS_ROOT
        config[:database] = File.expand_path(config[:database], rails_root)
      end
    end
  end

  module SQLite3
    def self.extended(base)
      base.class.class_eval do
        alias_chained_method :insert, :query_dirty, :insert
      end
    end

    def self.adapter_matcher(name, *)
      name =~ /sqlite/i ? self : false
    end

    def self.column_selector
      [/sqlite/i, lambda {|cfg,col| col.extend(::JdbcSpec::SQLite3::Column)}]
    end

    def self.jdbc_connection_class
      ::ActiveRecord::ConnectionAdapters::Sqlite3JdbcConnection
    end

    module Column
      def init_column(name, default, *args)
        @default = '' if default =~ /NULL/
      end

      def type_cast(value)
        return nil if value.nil?
        case type
        when :string   then value
        when :integer  then JdbcSpec::SQLite3::Column.cast_to_integer(value)
        when :primary_key then defined?(value.to_i) ? value.to_i : (value ? 1 : 0)
        when :float    then value.to_f
        when :datetime then JdbcSpec::SQLite3::Column.cast_to_date_or_time(value)
        when :date then JdbcSpec::SQLite3::Column.cast_to_date_or_time(value)
        when :time     then JdbcSpec::SQLite3::Column.cast_to_time(value)
        when :decimal  then self.class.value_to_decimal(value)
        when :boolean  then self.class.value_to_boolean(value)
        else value
        end
      end

      def type_cast_code(var_name)
        case type
          when :integer  then "JdbcSpec::SQLite3::Column.cast_to_integer(#{var_name})"
          when :datetime then "JdbcSpec::SQLite3::Column.cast_to_date_or_time(#{var_name})"
          when :date     then "JdbcSpec::SQLite3::Column.cast_to_date_or_time(#{var_name})"
          when :time     then "JdbcSpec::SQLite3::Column.cast_to_time(#{var_name})"
        else
          super
        end
      end

      private
      def simplified_type(field_type)
        case field_type
        when /boolean/i                        then :boolean
        when /text/i                           then :text
        when /varchar/i                        then :string
        when /int/i                            then :integer
        when /float/i                          then :float
        when /real/i                           then @scale == 0 ? :integer : :decimal
        when /datetime/i                       then :datetime
        when /date/i                           then :date
        when /time/i                           then :time
        when /blob/i                           then :binary
        end
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

      def self.cast_to_integer(value)
        return nil if value =~ /NULL/ or value.to_s.empty? or value.nil?
        return (value.to_i) ? value.to_i : (value ? 1 : 0)
      end

      def self.cast_to_date_or_time(value)
        return value if value.is_a? Date
        return nil if value.blank?
        guess_date_or_time((value.is_a? Time) ? value : cast_to_time(value))
      end

      def self.cast_to_time(value)
        return value if value.is_a? Time
        time_array = ParseDate.parsedate value
        time_array[0] ||= 2000; time_array[1] ||= 1; time_array[2] ||= 1;
        Time.send(ActiveRecord::Base.default_timezone, *time_array) rescue nil
      end

      def self.guess_date_or_time(value)
        (value.hour == 0 and value.min == 0 and value.sec == 0) ?
        Date.new(value.year, value.month, value.day) : value
      end
    end

    def adapter_name #:nodoc:
      'SQLite'
    end

    def supports_count_distinct? #:nodoc:
      sqlite_version >= '3.2.6'
    end

    def supports_autoincrement? #:nodoc:
      sqlite_version >= '3.1.0'
    end

    def sqlite_version
      @sqlite_version ||= select_value('select sqlite_version(*)')
    end

    def modify_types(tp)
      tp[:primary_key] = "INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL"
      tp[:string] = { :name => "VARCHAR", :limit => 255 }
      tp[:float] = { :name => "REAL" }
      tp[:decimal] = { :name => "REAL" }
      tp[:datetime] = { :name => "DATETIME" }
      tp[:timestamp] = { :name => "DATETIME" }
      tp[:time] = { :name => "TIME" }
      tp[:date] = { :name => "DATE" }
      tp[:boolean] = { :name => "BOOLEAN" }
      tp
    end

    def quote(value, column = nil) # :nodoc:
      return value.quoted_id if value.respond_to?(:quoted_id)
      case value
      when String
        if column && column.type == :binary
          "'#{quote_string(column.class.string_to_binary(value))}'"
        elsif column && [:integer, :float].include?(column.type)
          (column.type == :integer ? value.to_i : value.to_f).to_s
        elsif column && column.respond_to?(:primary) && column.primary && column.klass != String
          value.to_i.to_s
        else
          "'#{quote_string(value)}'"
        end
      else super
      end
    end

    def quote_column_name(name) #:nodoc:
      name = name.to_s
      # Did not find reference on values needing quoting, but these
      # happen in AR unit tests
      if name == "references" || name =~ /-/
        %Q("#{name}") 
      else
        name
      end
    end

    def quote_string(str)
      str.gsub(/'/, "''")
    end

    def quoted_true
      %Q{'t'}
    end

    def quoted_false
      %Q{'f'}
    end

    def add_column(table_name, column_name, type, options = {})
      if option_not_null = options[:null] == false
        option_not_null = options.delete(:null)
      end
      add_column_sql = "ALTER TABLE #{quote_table_name(table_name)} ADD #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
      add_column_options!(add_column_sql, options)
      execute(add_column_sql)
      if option_not_null
        alter_column_sql = "ALTER TABLE #{quote_table_name(table_name)} ALTER #{quote_column_name(column_name)} NOT NULL"
      end
    end

    def remove_column(table_name, *column_names) #:nodoc:
      column_names.flatten.each do |column_name|
        alter_table(table_name) do |definition|
          definition.columns.delete(definition[column_name])
        end
      end
    end
    alias :remove_columns :remove_column

    def change_column(table_name, column_name, type, options = {}) #:nodoc:
      alter_table(table_name) do |definition|
        include_default = options_include_default?(options)
        definition[column_name].instance_eval do
          self.type    = type
          self.limit   = options[:limit] if options.include?(:limit)
          self.default = options[:default] if include_default
          self.null    = options[:null] if options.include?(:null)
        end
      end
    end

    def change_column_default(table_name, column_name, default) #:nodoc:
      alter_table(table_name) do |definition|
        definition[column_name].default = default
      end
    end

    def rename_column(table_name, column_name, new_column_name) #:nodoc:
      unless columns(table_name).detect{|c| c.name == column_name.to_s }
        raise ActiveRecord::ActiveRecordError, "Missing column #{table_name}.#{column_name}"
      end
      alter_table(table_name, :rename => {column_name.to_s => new_column_name.to_s})
    end

    def rename_table(name, new_name)
      execute "ALTER TABLE #{name} RENAME TO #{new_name}"
    end

    def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) #:nodoc:
      log(sql,name) do
        @connection.execute_update(sql)
      end
      table = sql.split(" ", 4)[2]
      id_value || last_insert_id(table, nil)
    end

    def last_insert_id(table, sequence_name)
      Integer(select_value("SELECT SEQ FROM SQLITE_SEQUENCE WHERE NAME = '#{table}'"))
    end

    def add_limit_offset!(sql, options) #:nodoc:
      if options[:limit]
        sql << " LIMIT #{options[:limit]}"
        sql << " OFFSET #{options[:offset]}" if options[:offset]
      end
    end

    def tables(name = nil) #:nodoc:
      sql = <<-SQL
        SELECT name
        FROM sqlite_master
        WHERE type = 'table' AND NOT name = 'sqlite_sequence'
      SQL

      select_rows(sql, name).map do |row|
        row[0]
      end
    end

    def remove_index(table_name, options = {})
      execute "DROP INDEX #{quote_column_name(index_name(table_name, options))}"
    end

    def indexes(table_name, name = nil)
      result = select_rows("SELECT name, sql FROM sqlite_master WHERE tbl_name = '#{table_name}' AND type = 'index'", name)

      result.collect do |row|
        name = row[0]
        index_sql = row[1]
        unique = (index_sql =~ /unique/i)
        cols = index_sql.match(/\((.*)\)/)[1].gsub(/,/,' ').split
        ::ActiveRecord::ConnectionAdapters::IndexDefinition.new(table_name, name, unique, cols)
      end
    end
    
    def primary_key(table_name) #:nodoc:
      column = table_structure(table_name).find {|field| field['pk'].to_i == 1}
      column ? column['name'] : nil
    end

    def recreate_database(name)
      tables.each{ |table| drop_table(table) }
    end

    def _execute(sql, name = nil)
      if ActiveRecord::ConnectionAdapters::JdbcConnection::select?(sql)
        @connection.execute_query(sql)
      else
        affected_rows = @connection.execute_update(sql)
        ActiveRecord::ConnectionAdapters::JdbcConnection::insert?(sql) ? last_insert_id(sql.split(" ", 4)[2], nil) : affected_rows
      end
    end
    
    def select(sql, name=nil)
      execute(sql, name).map do |row|
        record = {}
        row.each_key do |key|
          if key.is_a?(String)
            record[key.sub(/^"?\w+"?\./, '')] = row[key]
          end
        end
        record
      end
    end
    
    def table_structure(table_name)
      structure = @connection.execute_query("PRAGMA table_info(#{quote_table_name(table_name)})")
      raise ActiveRecord::StatementInvalid, "Could not find table '#{table_name}'" if structure.empty?
      structure
    end
    
    def columns(table_name, name = nil) #:nodoc:        
      table_structure(table_name).map do |field|
        ::ActiveRecord::ConnectionAdapters::JdbcColumn.new(@config, field['name'], field['dflt_value'], field['type'], field['notnull'] == 0)
      end
    end
    
     # SELECT ... FOR UPDATE is redundant since the table is locked.
    def add_lock!(sql, options) #:nodoc:
      sql
    end
    
    protected
      include JdbcSpec::MissingFunctionalityHelper
  end
end

module ActiveRecord
  module ConnectionAdapters
    class JdbcColumn < Column
      def self.string_to_binary(value)
        value.gsub(/\0|%/n) do |b|
          case b
            when "\0" then "%00"
            when "\%"  then "%25"
          end
        end
      end

      def self.binary_to_string(value)
        value.gsub(/%00|%25/n) do |b|
          case b
            when "%00" then "\0"
            when "%25" then "%"
          end
        end
      end
    end
  end
end

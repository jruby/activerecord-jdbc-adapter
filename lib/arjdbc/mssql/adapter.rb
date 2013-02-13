require 'strscan'
require 'arjdbc/mssql/utils'
require 'arjdbc/mssql/tsql_methods'
require 'arjdbc/mssql/limit_helpers'
require 'arjdbc/mssql/lock_helpers'
require 'arjdbc/jdbc/serialized_attributes_helper'

module ArJdbc
  module MSSQL
    include Utils
    include TSqlMethods

    @@_lob_callback_added = nil
    
    def self.extended(base)
      unless @@_lob_callback_added
        ActiveRecord::Base.class_eval do
          def after_save_with_mssql_lob
            self.class.columns.select { |c| c.sql_type =~ /image/i }.each do |column|
              value = ::ArJdbc::SerializedAttributesHelper.dump_column_value(self, column)
              next if value.nil? || (value == '')

              connection.write_large_object(
                column.type == :binary, column.name, 
                self.class.table_name, self.class.primary_key, 
                quote_value(id), value
              )
            end
          end
        end

        ActiveRecord::Base.after_save :after_save_with_mssql_lob
        @@_lob_callback_added = true
      end
      
      if ( version = base.sqlserver_version ) == '2000'
        extend LimitHelpers::SqlServer2000AddLimitOffset
      else
        extend LimitHelpers::SqlServerAddLimitOffset
      end
      base.config[:sqlserver_version] ||= version
    end

    def self.column_selector
      [ /sqlserver|tds|Microsoft SQL/i, lambda { |cfg, column| column.extend(::ArJdbc::MSSQL::Column) } ]
    end

    def self.jdbc_connection_class
      ::ActiveRecord::ConnectionAdapters::MSSQLJdbcConnection
    end

    def self.arel2_visitors(config)
      require 'arel/visitors/sql_server'
      visitors = config[:sqlserver_version] == '2000' ? 
        ::Arel::Visitors::SQLServer2000 : ::Arel::Visitors::SQLServer
      { 'mssql' => visitors, 'jdbcmssql' => visitors, 'sqlserver' => visitors }
    end

    def sqlserver_version
      @sqlserver_version ||= begin
        config_version = config[:sqlserver_version]
        config_version ? config_version.to_s :
          select_value("SELECT @@version")[/Microsoft SQL Server\s+(\d{4})/, 1]
      end
    end

    def modify_types(types) #:nodoc:
      super(types)
      types[:string] = { :name => "NVARCHAR", :limit => 255 }
      if sqlserver_2000?
        types[:text] = { :name => "NTEXT" }
      else
        types[:text] = { :name => "NVARCHAR(MAX)" }
      end
      types[:primary_key] = "int NOT NULL IDENTITY(1, 1) PRIMARY KEY"
      types[:integer][:limit] = nil
      types[:boolean] = { :name => "bit" }
      types[:binary] = { :name => "image" }
      types
    end

    def type_to_sql(type, limit = nil, precision = nil, scale = nil) #:nodoc:
      # MSSQL's NVARCHAR(n | max) column supports either a number between 1 and
      # 4000, or the word "MAX", which corresponds to 2**30-1 UCS-2 characters.
      #
      # It does not accept NVARCHAR(1073741823) here, so we have to change it
      # to NVARCHAR(MAX), even though they are logically equivalent.
      #
      # MSSQL Server 2000 is skipped here because I don't know how it will behave.
      #
      # See: http://msdn.microsoft.com/en-us/library/ms186939.aspx
      if type.to_s == 'string' && limit == 1073741823 && ! sqlserver_2000?
        'NVARCHAR(MAX)'
      elsif %w( boolean date datetime ).include?(type.to_s)
        super(type) # cannot specify limit/precision/scale with these types
      else
        super # TSqlMethods#type_to_sql
      end
    end

    module Column
      include LockHelpers::SqlServerAddLock

      attr_accessor :identity, :is_special

      def simplified_type(field_type)
        case field_type
        when /int|bigint|smallint|tinyint/i           then :integer
        when /numeric/i                               then (@scale.nil? || @scale == 0) ? :integer : :decimal
        when /float|double|money|real|smallmoney/i    then :decimal
        when /datetime|smalldatetime/i                then :datetime
        when /timestamp/i                             then :timestamp
        when /time/i                                  then :time
        when /date/i                                  then :date
        when /text|ntext|xml/i                        then :text
        when /binary|image|varbinary/i                then :binary
        when /char|nchar|nvarchar|string|varchar/i    then (@limit == 1073741823 ? (@limit = nil; :text) : :string)
        when /bit/i                                   then :boolean
        when /uniqueidentifier/i                      then :string
        else
          super
        end
      end

      def default_value(value)
        return $1 if value =~ /^\(N?'(.*)'\)$/
        value
      end

      def type_cast(value)
        return nil if value.nil?
        case type
        when :integer then value.delete('()').to_i rescue unquote(value).to_i rescue value ? 1 : 0
        when :primary_key then value == true || value == false ? value == true ? 1 : 0 : value.to_i
        when :decimal   then self.class.value_to_decimal(unquote(value))
        when :datetime  then cast_to_datetime(value)
        when :timestamp then cast_to_time(value)
        when :time      then cast_to_time(value)
        when :date      then cast_to_date(value)
        when :boolean   then value == true or (value =~ /^t(rue)?$/i) == 0 or unquote(value)=="1"
        when :binary    then unquote value
        else value
        end
      end

      def extract_limit(sql_type)
        case sql_type
        when /text|ntext|xml|binary|image|varbinary|bit/
          nil
        else
          super
        end
      end

      def is_utf8?
        sql_type =~ /nvarchar|ntext|nchar/i
      end

      def unquote(value)
        value.to_s.sub(/\A\([\(\']?/, "").sub(/[\'\)]?\)\Z/, "")
      end

      def cast_to_time(value)
        return value if value.is_a?(Time)
        DateTime.parse(value).to_time rescue nil
      end

      def cast_to_date(value)
        return value if value.is_a?(Date)
        return Date.parse(value) rescue nil
      end

      def cast_to_datetime(value)
        if value.is_a?(Time)
          if value.year != 0 and value.month != 0 and value.day != 0
            return value
          else
            return Time.mktime(2000, 1, 1, value.hour, value.min, value.sec) rescue nil
          end
        end
        if value.is_a?(DateTime)
          begin
            # Attempt to convert back to a Time, but it could fail for dates significantly in the past/future.
            return Time.mktime(value.year, value.mon, value.day, value.hour, value.min, value.sec)
          rescue ArgumentError
            return value
          end
        end

        return cast_to_time(value) if value.is_a?(Date) or value.is_a?(String) rescue nil

        return value.is_a?(Date) ? value : nil
      end

      # These methods will only allow the adapter to insert binary data with a length of 7K or less
      # because of a SQL Server statement length policy.
      def self.string_to_binary(value)
        ''
      end

    end

    def quote(value, column = nil)
      return value.quoted_id if value.respond_to?(:quoted_id)

      case value
      # SQL Server 2000 doesn't let you insert an integer into a NVARCHAR
      # column, so we include Integer here.
      when String, ActiveSupport::Multibyte::Chars, Integer
        value = value.to_s
        column_type = column && column.type
        if column_type == :binary
          "'#{quote_string(ArJdbc::MSSQL::Column.string_to_binary(value))}'" # ' (for ruby-mode)
        elsif column_type == :integer
          value.to_i.to_s
        elsif column_type == :float
          value.to_f.to_s
        elsif ! column.respond_to?(:is_utf8?) || column.is_utf8?
          "N'#{quote_string(value)}'" # ' (for ruby-mode)
        else
          super
        end
      when TrueClass  then '1'
      when FalseClass then '0'
      else super
      end
    end

    def quote_table_name(name)
      quote_column_name(name)
    end

    def quote_column_name(name)
      name.to_s.split('.').map do |n| # "[#{name}]"
        n =~ /^\[.*\]$/ ? n : "[#{n.gsub(']', ']]')}]"
      end.join('.')
    end

    ADAPTER_NAME = 'MSSQL'
    
    def adapter_name # :nodoc:
      ADAPTER_NAME
    end

    def change_order_direction(order)
      asc, desc = /\bASC\b/i, /\bDESC\b/i
      order.split(",").collect do |fragment|
        case fragment
        when desc  then fragment.gsub(desc, "ASC")
        when asc   then fragment.gsub(asc, "DESC")
        else "#{fragment.split(',').join(' DESC,')} DESC"
        end
      end.join(",")
    end

    def supports_ddl_transactions?
      true
    end

    def recreate_database(name, options = {})
      drop_database(name)
      create_database(name, options)
    end

    def drop_database(name)
      execute "USE master"
      execute "DROP DATABASE #{name}"
    end

    def create_database(name, options = {})
      execute "CREATE DATABASE #{name}"
      execute "USE #{name}"
    end

    def rename_table(name, new_name)
      clear_cached_table(name)
      execute "EXEC sp_rename '#{name}', '#{new_name}'"
    end

    # Adds a new column to the named table.
    # See TableDefinition#column for details of the options you can use.
    def add_column(table_name, column_name, type, options = {})
      clear_cached_table(table_name)
      add_column_sql = "ALTER TABLE #{table_name} ADD #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
      add_column_options!(add_column_sql, options)
      # TODO: Add support to mimic date columns, using constraints to mark them as such in the database
      # add_column_sql << " CONSTRAINT ck__#{table_name}__#{column_name}__date_only CHECK ( CONVERT(CHAR(12), #{quote_column_name(column_name)}, 14)='00:00:00:000' )" if type == :date
      execute(add_column_sql)
    end

    def rename_column(table, column, new_column_name)
      clear_cached_table(table)
      execute "EXEC sp_rename '#{table}.#{column}', '#{new_column_name}'"
    end

    def change_column(table_name, column_name, type, options = {}) #:nodoc:
      clear_cached_table(table_name)
      change_column_type(table_name, column_name, type, options)
      change_column_default(table_name, column_name, options[:default]) if options_include_default?(options)
    end

    def change_column_type(table_name, column_name, type, options = {}) #:nodoc:
      clear_cached_table(table_name)
      sql = "ALTER TABLE #{table_name} ALTER COLUMN #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
      if options.has_key?(:null)
        sql += (options[:null] ? " NULL" : " NOT NULL")
      end
      execute(sql)
    end

    def change_column_default(table_name, column_name, default) #:nodoc:
      clear_cached_table(table_name)
      remove_default_constraint(table_name, column_name)
      unless default.nil?
        execute "ALTER TABLE #{table_name} ADD CONSTRAINT DF_#{table_name}_#{column_name} DEFAULT #{quote(default)} FOR #{quote_column_name(column_name)}"
      end
    end

    def remove_column(table_name, column_name)
      clear_cached_table(table_name)
      remove_check_constraints(table_name, column_name)
      remove_default_constraint(table_name, column_name)
      execute "ALTER TABLE #{table_name} DROP COLUMN [#{column_name}]"
    end

    def remove_default_constraint(table_name, column_name)
      clear_cached_table(table_name)
      if sqlserver_2000?
        # NOTE: since SQLServer 2005 these are provided as sys.sysobjects etc.
        # but only due backwards-compatibility views and should be avoided ...
        defaults = select_values "SELECT d.name" <<
          " FROM sysobjects d, syscolumns c, sysobjects t" <<
          " WHERE c.cdefault = d.id AND c.name = '#{column_name}'" <<
          " AND t.name = '#{table_name}' AND c.id = t.id"
      else
        defaults = select_values "SELECT d.name FROM sys.tables t" <<
          " JOIN sys.default_constraints d ON d.parent_object_id = t.object_id" <<
          " JOIN sys.columns c ON c.object_id = t.object_id AND c.column_id = d.parent_column_id" <<
          " WHERE t.name = '#{table_name}' AND c.name = '#{column_name}'"
      end
      defaults.each do |def_name|
        execute "ALTER TABLE #{table_name} DROP CONSTRAINT #{def_name}"
      end
    end

    def remove_check_constraints(table_name, column_name)
      clear_cached_table(table_name)
      constraints = select_values "SELECT constraint_name" <<
        " FROM information_schema.constraint_column_usage" <<
        " WHERE table_name = '#{table_name}' AND column_name = '#{column_name}'"
      constraints.each do |constraint_name|
        execute "ALTER TABLE #{table_name} DROP CONSTRAINT #{constraint_name}"
      end
    end

    def remove_index(table_name, options = {})
      execute "DROP INDEX #{table_name}.#{index_name(table_name, options)}"
    end

    def table_exists?(name)
      jdbc_columns(name) rescue nil
    end
    
    SKIP_COLUMNS_TABLE_NAMES_RE = /^information_schema\./i # :nodoc:
    
    def columns(table_name, name = nil)
      # It's possible for table_name to be an empty string, or nil, if something 
      # attempts to issue SQL which doesn't involve a table. 
      # IE. "SELECT 1" or "SELECT * FROM someFunction()".
      return [] if table_name.blank?
      
      table_name = unquote_table_name(table_name)

      return [] if table_name =~ SKIP_COLUMNS_TABLE_NAMES_RE
      
      unless (@table_columns ||= {})[table_name]
        @table_columns[table_name] = super
        @table_columns[table_name].each do |column|
          column.identity = true if column.sql_type =~ /identity/i
          column.is_special = true if column.sql_type =~ /text|ntext|image|xml/i
        end
      end
      @table_columns[table_name]
    end

    # Turns IDENTITY_INSERT ON for table during execution of the block
    # N.B. This sets the state of IDENTITY_INSERT to OFF after the
    # block has been executed without regard to its previous state
    def with_identity_insert_enabled(table_name)
      set_identity_insert(table_name, true)
      yield
    ensure
      set_identity_insert(table_name, false)
    end

    def set_identity_insert(table_name, enable = true)
      execute "SET IDENTITY_INSERT #{table_name} #{enable ? 'ON' : 'OFF'}"
    rescue Exception => e
      raise ActiveRecord::ActiveRecordError, "IDENTITY_INSERT could not be turned" + 
            " #{enable ? 'ON' : 'OFF'} for table #{table_name} due : #{e.inspect}"
    end

    def identity_column(table_name)
      for column in columns(table_name)
        return column.name if column.identity
      end
      nil
    end
    
    def query_requires_identity_insert?(sql)
      table_name = get_table_name(sql)
      id_column = identity_column(table_name)
      if sql.strip =~ /insert into [^ ]+ ?\((.+?)\)/i
        insert_columns = $1.split(/, */).map(&method(:unquote_column_name))
        return table_name if insert_columns.include?(id_column)
      end
    end
    
    def determine_order_clause(sql)
      return $1 if sql =~ /ORDER BY (.*)$/
      table_name = get_table_name(sql)
      "#{table_name}.#{determine_primary_key(table_name)}"
    end

    def determine_primary_key(table_name)
      primary_key = columns(table_name).detect { |column| column.primary || column.identity }
      return primary_key.name if primary_key
      # Look for an id column and return it, 
      # without changing case, to cover DBs with a case-sensitive collation :
      columns(table_name).each { |column| return column.name if column.name =~ /^id$/i }
      # Give up and provide something which is going to crash almost certainly
      columns(table_name)[0].name
    end

    def clear_cached_table(name)
      (@table_columns ||= {}).delete(name.to_s)
    end

    def reset_column_information
      @table_columns = nil if defined? @table_columns
    end
    
    private
    
    def _execute(sql, name = nil)
      # Match the start of the SQL to determine appropriate behavior.
      # Be aware of multi-line SQL which might begin with 'create stored_proc' 
      # and contain 'insert into ...' lines.
      # TODO test and refactor using `self.class.insert?(sql)` etc
      # NOTE: ignoring comment blocks prior to the first statement ?!
      if sql.lstrip =~ /\Ainsert/i # self.class.insert?(sql)
        if query_requires_identity_insert?(sql)
          table_name = get_table_name(sql)
          with_identity_insert_enabled(table_name) do
            @connection.execute_insert(sql)
          end
        else
          @connection.execute_insert(sql)
        end
      elsif sql.lstrip =~ /\A\(?\s*(select|show)/i # self.class.select?(sql)
        sql = repair_special_columns(sql)
        @connection.execute_query(sql)
      else # sql.lstrip =~ /\A(create|exec)/i
        @connection.execute_update(sql)
      end
    end
    
    def repair_special_columns(sql)
      qualified_table_name = get_table_name(sql, true)
      special_columns = get_special_columns(qualified_table_name)
      for column in special_columns.to_a
        sql.gsub!(Regexp.new(" #{column} = "), " #{column} LIKE ")
        sql.gsub!(/ORDER BY #{column.to_s}/i, '')
      end if special_columns
      sql
    end

    def get_special_columns(qualified_table_name)
      special = []
      columns(qualified_table_name).each do |column|
        special << column.name if column.is_special
      end
      special
    end
    
    def sqlserver_2000?
      sqlserver_version <= '2000'
    end
    
  end
end


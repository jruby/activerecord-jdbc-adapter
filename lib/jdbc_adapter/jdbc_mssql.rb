require 'jdbc_adapter/tsql_helper'

module ::JdbcSpec
  module MsSQL
    include TSqlMethods

    def self.extended(mod)
      unless @lob_callback_added
        ActiveRecord::Base.class_eval do
          def after_save_with_mssql_lob
          self.class.columns.select { |c| c.sql_type =~ /image/i }.each do |c|
            value = self[c.name]
            value = value.to_yaml if unserializable_attribute?(c.name, c)
            next if value.nil?  || (value == '')

            connection.write_large_object(c.type == :binary, c.name, self.class.table_name, self.class.primary_key, quote_value(id), value)
          end
          end
        end

        ActiveRecord::Base.after_save :after_save_with_mssql_lob
        @lob_callback_added = true
      end
    end

    def self.adapter_matcher(name, *)
      name =~ /sqlserver|tds/i ? self : false
    end

    def self.column_selector
      [/sqlserver|tds/i, lambda {|cfg,col| col.extend(::JdbcSpec::MsSQL::Column)}]
    end

    module Column
      attr_accessor :identity, :is_special

      def simplified_type(field_type)
        case field_type
          when /int|bigint|smallint|tinyint/i                        then :integer
          when /numeric/i                                            then (@scale.nil? || @scale == 0) ? :integer : :decimal
          when /float|double|decimal|money|real|smallmoney/i         then :decimal
          when /date|datetime|smalldatetime/i                        then :datetime
          when /timestamp/i                                          then :timestamp
          when /time/i                                               then :time
          when /text|ntext/i                                         then :text
          when /binary|image|varbinary/i                             then :binary
          when /char|nchar|nvarchar|string|varchar/i                 then :string
          when /bit/i                                                then :boolean
          when /uniqueidentifier/i                                   then :string
        end
      end

      def type_cast(value)
        return nil if value.nil? || value == "(null)" || value == "(NULL)"
        case type
        when :string then unquote_string value
        # JWW START HACK
        # when :integer then unquote(value).to_i rescue value ? 1 : 0
        when :integer then value.to_i rescue unquote(value).to_i rescue value ? 1 : 0
        # JWW END HACK
        when :primary_key then value == true || value == false ? value == true ? 1 : 0 : value.to_i
        when :decimal   then self.class.value_to_decimal(unquote(value))
        when :datetime  then cast_to_datetime(value)
        when :timestamp then cast_to_time(value)
        when :time      then cast_to_time(value)
        when :date      then cast_to_datetime(value)
        when :boolean   then value == true or (value =~ /^t(rue)?$/i) == 0 or unquote(value)=="1"
        when :binary    then unquote value
        else value
        end
      end

      # JRUBY-2011: Match balanced quotes and parenthesis - 'text',('text') or (text)
      def unquote_string(value)
        # JWW imported change from git repo
        # value.sub(/^\((.*)\)$/,'\1').sub(/^'(.*)'$/,'\1')
        value.to_s.sub(/^\((.*)\)$/,'\1').sub(/^'(.*)'$/,'\1')
        # JWW END import
      end

      def unquote(value)
        value.to_s.sub(/\A\([\(\']?/, "").sub(/[\'\)]?\)\Z/, "")
      end

      def cast_to_time(value)
        return value if value.is_a?(Time)
        time_array = ParseDate.parsedate(value)
        return nil if !time_array.any?
        time_array[0] ||= 2000
        time_array[1] ||= 1
        time_array[2] ||= 1
        # PD START HACKE
        return Time.send(ActiveRecord::Base.default_timezone, *time_array) rescue nil

        # Try DateTime instead
        DateTime.new(*time_array[0..5]) rescue nil
        # PD HACK ENDE
      end

      def cast_to_datetime(value)
        if value.is_a?(Time)
          if value.year != 0 and value.month != 0 and value.day != 0
            return value
          else
            return Time.mktime(2000, 1, 1, value.hour, value.min, value.sec) rescue nil
          end
        end

        # JWW START HACK
        if value.is_a?(DateTime)
          begin
            return Time.mktime(value.year, value.mon, value.day, value.hour, value.min, value.sec)
          rescue ArgumentError
            return value
          end
        end
        # JWW END HACK

        return cast_to_time(value) if value.is_a?(Date)  || value.is_a?(String) rescue nil
        # JWW START HACK
        return value.is_a?(Date) ? value : nil
        # JWW END HACK
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
      when String, ActiveSupport::Multibyte::Chars
        value = value.to_s
        if column && column.type == :binary
          "'#{quote_string(JdbcSpec::MsSQL::Column.string_to_binary(value))}'" # ' (for ruby-mode)
        elsif column && [:integer, :float].include?(column.type)
          value = column.type == :integer ? value.to_i : value.to_f
          value.to_s
        else
          "'#{quote_string(value)}'" # ' (for ruby-mode)
        end
      when TrueClass             then '1'
      when FalseClass            then '0'
      # JWW START HACK
      #when Time, DateTime        then "'#{value.strftime("%Y%m%d %H:%M:%S")}'"
      #when Date                  then "'#{value.strftime("%Y%m%d")}'"
      #else                       super
      else
        if value.acts_like?(:time)
          "'#{value.strftime("%d %B %Y %H:%M:%S")}'"
        elsif value.acts_like?(:datetime)
          "'#{value.strftime("%d %B %Y %H:%M:%S")}'"
        elsif value.acts_like?(:date)
          "'#{value.strftime("%d %B %Y")}'"
        else
          super
        end
      # JWW END HACK
      end
    end

    def quote_string(string)
      string.gsub(/\'/, "''")
    end

    def quote_table_name(name)
      name
    end

    def quote_column_name(name)
      "[#{name}]"
    end

    # JWW imported from git repo
    def quoted_true
      quote true
    end

    def quoted_false
      quote false
    end
    # JWW end import

    # JWW added entire method from our other adapter
    def add_limit_offset!(sql, options)
      if options[:limit] and options[:offset]
        order_by = options[:order] unless options[:order].nil?
        order_by = "#{get_table_name( sql )}.id" if options[:order].nil?

        sql.sub!(/^\s*SELECT(\s+DISTINCT)?/i,
          "SELECT * FROM ( SELECT#{$1} TOP #{options[:offset] + options[:limit]} ROW_NUMBER() OVER (order by #{order_by}) as ss_rownum_, ")
        sql << " ) as tmp1 where ss_rownum_ > #{options[:offset]} and ss_rownum_ <= #{options[:offset] + options[:limit]}"
      elsif sql !~ /^\s*SELECT (@@|COUNT\()/i
        sql.sub!(/^\s*SELECT(\s+DISTINCT)?/i) do
          "SELECT#{$1} TOP #{options[:limit]}"
        end unless options[:limit].nil?
      end
    end
    # JWW END addition

    def change_order_direction(order)
      order.split(",").collect {|fragment|
        case fragment
        when  /\bDESC\b/i     then fragment.gsub(/\bDESC\b/i, "ASC")
        when  /\bASC\b/i      then fragment.gsub(/\bASC\b/i, "DESC")
        else                  String.new(fragment).split(',').join(' DESC,') + ' DESC'
        end
      }.join(",")
    end

    def recreate_database(name)
      drop_database(name)
      create_database(name)
    end

    def drop_database(name)
      execute "USE master"
      execute "DROP DATABASE #{name}"
    end

    def create_database(name)
      execute "CREATE DATABASE #{name}"
      execute "USE #{name}"
    end

      def rename_table(name, new_name)
        execute "EXEC sp_rename '#{name}', '#{new_name}'"
      end

      # Adds a new column to the named table.
      # See TableDefinition#column for details of the options you can use.
      def add_column(table_name, column_name, type, options = {})
        add_column_sql = "ALTER TABLE #{table_name} ADD #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
        add_column_options!(add_column_sql, options)
        # TODO: Add support to mimic date columns, using constraints to mark them as such in the database
        # add_column_sql << " CONSTRAINT ck__#{table_name}__#{column_name}__date_only CHECK ( CONVERT(CHAR(12), #{quote_column_name(column_name)}, 14)='00:00:00:000' )" if type == :date
        execute(add_column_sql)
      end

      def rename_column(table, column, new_column_name)
        execute "EXEC sp_rename '#{table}.#{column}', '#{new_column_name}'"
      end

      def change_column(table_name, column_name, type, options = {}) #:nodoc:
        sql_commands = ["ALTER TABLE #{table_name} ALTER COLUMN #{column_name} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"]
        if options_include_default?(options)
          remove_default_constraint(table_name, column_name)
          sql_commands << "ALTER TABLE #{table_name} ADD CONSTRAINT DF_#{table_name}_#{column_name} DEFAULT #{quote(options[:default], options[:column])} FOR #{column_name}"
        end
        sql_commands.each {|c|
          execute(c)
        }
      end
      def change_column_default(table_name, column_name, default) #:nodoc:
        remove_default_constraint(table_name, column_name)
        execute "ALTER TABLE #{table_name} ADD CONSTRAINT DF_#{table_name}_#{column_name} DEFAULT #{quote(default, column_name)} FOR #{column_name}"
      end
      def remove_column(table_name, column_name)
        remove_check_constraints(table_name, column_name)
        remove_default_constraint(table_name, column_name)
        execute "ALTER TABLE #{table_name} DROP COLUMN [#{column_name}]"
      end

      def remove_default_constraint(table_name, column_name)
        defaults = select "select def.name from sysobjects def, syscolumns col, sysobjects tab where col.cdefault = def.id and col.name = '#{column_name}' and tab.name = '#{table_name}' and col.id = tab.id"
        defaults.each {|constraint|
          execute "ALTER TABLE #{table_name} DROP CONSTRAINT #{constraint["name"]}"
        }
      end

      def remove_check_constraints(table_name, column_name)
        # TODO remove all constraints in single method
        constraints = select "SELECT CONSTRAINT_NAME FROM INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE where TABLE_NAME = '#{table_name}' and COLUMN_NAME = '#{column_name}'"
        constraints.each do |constraint|
          execute "ALTER TABLE #{table_name} DROP CONSTRAINT #{constraint["CONSTRAINT_NAME"]}"
        end
      end

      def remove_index(table_name, options = {})
        execute "DROP INDEX #{table_name}.#{index_name(table_name, options)}"
      end


      def columns(table_name, name = nil)
        # JWW HACK - copied from activerecord-sqlserver-adapter
        return [] if table_name.blank?
        table_name = table_name.to_s if table_name.is_a?(Symbol)
        table_name = table_name.gsub(/[\[\]]/, '')
        # JWW END HACK
        return [] if table_name =~ /^information_schema\./i
        cc = super
        cc.each do |col|
          col.identity = true if col.sql_type =~ /identity/i
          col.is_special = true if col.sql_type =~ /text|ntext|image/i
        end
        cc
      end

      def _execute(sql, name = nil, hint = nil)
        if hint == :insert or (hint.nil? and sql.lstrip =~ /^insert/i )
          if query_requires_identity_insert?(sql)
            table_name = get_table_name(sql)
            with_identity_insert_enabled(table_name) do
              id = @connection.execute_insert(sql)
            end
          else
            @connection.execute_insert(sql)
          end
        elsif hint == :select or (hint.nil? and sql.lstrip =~ /^\(?\s*(select|show)/i )
          repair_special_columns(sql)
          @connection.execute_query(sql)
        else
          @connection.execute_update(sql)
        end
      end


      private
      # Turns IDENTITY_INSERT ON for table during execution of the block
      # N.B. This sets the state of IDENTITY_INSERT to OFF after the
      # block has been executed without regard to its previous state

      def with_identity_insert_enabled(table_name, &block)
        set_identity_insert(table_name, true)
        yield
      ensure
        set_identity_insert(table_name, false)
      end

      def set_identity_insert(table_name, enable = true)
        execute "SET IDENTITY_INSERT #{table_name} #{enable ? 'ON' : 'OFF'}"
      rescue Exception => e
        raise ActiveRecord::ActiveRecordError, "IDENTITY_INSERT could not be turned #{enable ? 'ON' : 'OFF'} for table #{table_name}"
      end

      def get_table_name(sql)
        if sql =~ /^\s*insert\s+into\s+([^\(\s,]+)\s*|^\s*update\s+([^\(\s,]+)\s*/i
          $1
        elsif sql =~ /from\s+([^\(\s,]+)\s*/i
          name = $1

          if !name.split('.').empty? && name.split('.')[-1].start_with?('fn')
            return nil # looks like a function
          end

          return name
        else
          nil
        end
      end

      def identity_column(table_name)
        @table_columns = {} unless @table_columns
        @table_columns[table_name] = columns(table_name) if @table_columns[table_name] == nil
        @table_columns[table_name].each do |col|
          return col.name if col.identity
        end

        return nil
      end

      def query_requires_identity_insert?(sql)
        table_name = get_table_name(sql)
        id_column = identity_column(table_name)
        sql =~ /\[#{id_column}\]/ ? table_name : nil
      end

      def get_special_columns(table_name)
        special = []
        @table_columns ||= {}
        @table_columns[table_name] ||= columns(table_name)
        @table_columns[table_name].each do |col|
          special << col.name if col.is_special
        end
        special
      end

      def repair_special_columns(sql)
        special_cols = get_special_columns(get_table_name(sql))
        for col in special_cols.to_a
          sql.gsub!(Regexp.new(" #{col.to_s} = "), " #{col.to_s} LIKE ")
          sql.gsub!(/ORDER BY #{col.to_s}/i, '')
        end
        sql
      end
    end
  end


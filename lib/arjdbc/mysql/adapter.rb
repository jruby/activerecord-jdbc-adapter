require 'active_record/connection_adapters/abstract/schema_definitions'

module ::ArJdbc
  module MySQL
    def self.column_selector
      [/mysql/i, lambda {|cfg,col| col.extend(::ArJdbc::MySQL::Column)}]
    end

    def self.extended(adapter)
      adapter.execute("SET SQL_AUTO_IS_NULL=0")
    end

    module Column
      def extract_default(default)
        if sql_type =~ /blob/i || type == :text
          if default.blank?
            return null ? nil : ''
          else
            raise ArgumentError, "#{type} columns cannot have a default value: #{default.inspect}"
          end
        elsif missing_default_forged_as_empty_string?(default)
          nil
        else
          super
        end
      end

      def has_default?
        return false if sql_type =~ /blob/i || type == :text #mysql forbids defaults on blob and text columns
        super
      end

      def simplified_type(field_type)
        return :boolean if field_type =~ /tinyint\(1\)|bit/i
        return :string  if field_type =~ /enum/i
        super
      end

      # MySQL misreports NOT NULL column default when none is given.
      # We can't detect this for columns which may have a legitimate ''
      # default (string) but we can for others (integer, datetime, boolean,
      # and the rest).
      #
      # Test whether the column has default '', is not null, and is not
      # a type allowing default ''.
      def missing_default_forged_as_empty_string?(default)
        type != :string && !null && default == ''
      end
    end

    def modify_types(tp)
      tp[:primary_key] = "int(11) DEFAULT NULL auto_increment PRIMARY KEY"
      tp[:integer] = { :name => 'int', :limit => 4 }
      tp[:decimal] = { :name => "decimal" }
      tp[:timestamp] = { :name => "datetime" }
      tp[:datetime][:limit] = nil
      tp
    end

    def adapter_name #:nodoc:
      'MySQL'
    end

    # QUOTING ==================================================

    def quote(value, column = nil)
      return value.quoted_id if value.respond_to?(:quoted_id)

      if column && column.type == :primary_key
        value.to_s
      elsif column && String === value && column.type == :binary && column.class.respond_to?(:string_to_binary)
        s = column.class.string_to_binary(value).unpack("H*")[0]
        "x'#{s}'"
      elsif BigDecimal === value
        "'#{value.to_s("F")}'"
      else
        super
      end
    end

    def quoted_true
        "1"
    end

    def quoted_false
        "0"
    end

    def begin_db_transaction #:nodoc:
      @connection.begin
    rescue Exception
      # Transactions aren't supported
    end

    def commit_db_transaction #:nodoc:
      @connection.commit
    rescue Exception
      # Transactions aren't supported
    end

    def rollback_db_transaction #:nodoc:
      @connection.rollback
    rescue Exception
      # Transactions aren't supported
    end

    def supports_savepoints? #:nodoc:
      true
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

    def disable_referential_integrity(&block) #:nodoc:
      old = select_value("SELECT @@FOREIGN_KEY_CHECKS")
      begin
        update("SET FOREIGN_KEY_CHECKS = 0")
        yield
      ensure
        update("SET FOREIGN_KEY_CHECKS = #{old}")
      end
    end

    # SCHEMA STATEMENTS ========================================

    def structure_dump #:nodoc:
      if supports_views?
        sql = "SHOW FULL TABLES WHERE Table_type = 'BASE TABLE'"
      else
        sql = "SHOW TABLES"
      end

      select_all(sql).inject("") do |structure, table|
        table.delete('Table_type')

        hash = show_create_table(table.to_a.first.last)

        if(table = hash["Create Table"])
          structure += table + ";\n\n"
        elsif(view = hash["Create View"])
          structure += view + ";\n\n"
        end
      end
    end

    def recreate_database(name, options = {}) #:nodoc:
      drop_database(name)
      create_database(name, options)
    end

    def character_set(options) #:nodoc:
      str = "CHARACTER SET `#{options[:charset] || 'utf8'}`"
      str += " COLLATE `#{options[:collation]}`" if options[:collation]
      str
    end
    private :character_set

    def create_database(name, options = {}) #:nodoc:
      execute "CREATE DATABASE `#{name}` DEFAULT #{character_set(options)}"
    end

    def drop_database(name) #:nodoc:
      execute "DROP DATABASE IF EXISTS `#{name}`"
    end

    def current_database
      select_one("SELECT DATABASE() as db")["db"]
    end

    def create_table(name, options = {}) #:nodoc:
      super(name, {:options => "ENGINE=InnoDB #{character_set(options)}"}.merge(options))
    end

    def rename_table(name, new_name)
      execute "RENAME TABLE #{quote_table_name(name)} TO #{quote_table_name(new_name)}"
    end

    def change_column_default(table_name, column_name, default) #:nodoc:
      current_type = select_one("SHOW COLUMNS FROM #{quote_table_name(table_name)} LIKE '#{column_name}'")["Type"]

      execute("ALTER TABLE #{quote_table_name(table_name)} CHANGE #{quote_column_name(column_name)} #{quote_column_name(column_name)} #{current_type} DEFAULT #{quote(default)}")
    end

    def change_column(table_name, column_name, type, options = {}) #:nodoc:
      unless options_include_default?(options)
        if column = columns(table_name).find { |c| c.name == column_name.to_s }
          options[:default] = column.default
        else
          raise "No such column: #{table_name}.#{column_name}"
        end
      end

      change_column_sql = "ALTER TABLE #{quote_table_name(table_name)} CHANGE #{quote_column_name(column_name)} #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
      add_column_options!(change_column_sql, options)
      execute(change_column_sql)
    end

    def rename_column(table_name, column_name, new_column_name) #:nodoc:
      cols = select_one("SHOW COLUMNS FROM #{quote_table_name(table_name)} LIKE '#{column_name}'")
      current_type = cols["Type"] || cols["COLUMN_TYPE"]
      execute "ALTER TABLE #{quote_table_name(table_name)} CHANGE #{quote_table_name(column_name)} #{quote_column_name(new_column_name)} #{current_type}"
    end

    def add_limit_offset!(sql, options) #:nodoc:
      limit, offset = options[:limit], options[:offset]
      if limit && offset
        sql << " LIMIT #{offset.to_i}, #{sanitize_limit(limit)}"
      elsif limit
        sql << " LIMIT #{sanitize_limit(limit)}"
      elsif offset
        sql << " OFFSET #{offset.to_i}"
      end
      sql
    end

    def show_variable(var)
      res = execute("show variables like '#{var}'")
      row = res.detect {|row| row["Variable_name"] == var }
      row && row["Value"]
    end

    def charset
      show_variable("character_set_database")
    end

    def collation
      show_variable("collation_database")
    end

    def type_to_sql(type, limit = nil, precision = nil, scale = nil)
      return super unless type.to_s == 'integer'

      case limit
      when 1; 'tinyint'
      when 2; 'smallint'
      when 3; 'mediumint'
      when nil, 4, 11; 'int(11)'  # compatibility with MySQL default
      when 5..8; 'bigint'
      else raise(ActiveRecordError, "No integer type has byte size #{limit}")
      end
    end

    protected
    def translate_exception(exception, message)
      return super unless exception.respond_to?(:errno)

      case exception.errno
      when 1062
        ::ActiveRecord::RecordNotUnique.new(message, exception)
      when 1452
        ::ActiveRecord::InvalidForeignKey.new(message, exception)
      else
        super
      end
    end

    private
    def show_create_table(table)
      select_one("SHOW CREATE TABLE #{quote_table_name(table)}")
    end

    def supports_views?
      false
    end
  end
end

module ActiveRecord::ConnectionAdapters
  class MysqlColumn < JdbcColumn
    include ArJdbc::MySQL::Column

    def call_discovered_column_callbacks(*)
    end
  end

  class MysqlAdapter < JdbcAdapter
    include ArJdbc::MySQL

    def adapter_spec(config)
      # return nil to avoid extending ArJdbc::MySQL, which we've already done
    end

    def jdbc_column_class
      ActiveRecord::ConnectionAdapters::MysqlColumn
    end
  end
end

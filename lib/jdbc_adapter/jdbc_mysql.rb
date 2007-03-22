require 'active_record/connection_adapters/abstract/schema_definitions'

module JdbcSpec
  module MySQL
    def modify_types(tp)
      tp[:primary_key] = "int(11) DEFAULT NULL auto_increment PRIMARY KEY"
      tp[:decimal] = { :name => "decimal" }
      tp[:timestamp]= { :name => "datetime" }
      tp
    end
    
    # QUOTING ==================================================
    
    def quote(value, column = nil)
      if column && column.type == :primary_key
        return value.to_s
      end
      super
    end
    
    def quote_column_name(name) #:nodoc:
        "`#{name}`"
    end

    # from active_record/vendor/mysql.rb
    def quote_string(str) #:nodoc:
      str.gsub(/([\0\n\r\032\'\"\\])/) do
        case $1
        when "\0" then "\\0"
        when "\n" then "\\n"
        when "\r" then "\\r"
        when "\032" then "\\Z"
        else "\\"+$1
        end
      end
    end
    
    def quoted_true
        "1"
    end
    
    def quoted_false
        "0"
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
        structure += select_one("SHOW CREATE TABLE #{table.to_a.first.last}")["Create Table"] + ";\n\n"
      end
    end
    
    def recreate_database(name) #:nodoc:
      drop_database(name)
      create_database(name)
    end
    
    def create_database(name) #:nodoc:
      execute "CREATE DATABASE `#{name}`"
    end
    
    def drop_database(name) #:nodoc:
      execute "DROP DATABASE IF EXISTS `#{name}`"
    end
    
    def current_database
      select_one("SELECT DATABASE() as db")["db"]
    end
    
    def indexes(table_name, name = nil)#:nodoc:
      @connection.indexes(table_name)      
    end
    
    def create_table(name, options = {}) #:nodoc:
      super(name, {:options => "ENGINE=InnoDB"}.merge(options))
    end
    
    def rename_table(name, new_name)
      execute "RENAME TABLE #{name} TO #{new_name}"
    end  
    
    def change_column_default(table_name, column_name, default) #:nodoc:
      current_type = select_one("SHOW COLUMNS FROM #{table_name} LIKE '#{column_name}'")["type"]

      type, limit = native_sql_to_type(current_type)
      
      change_column(table_name, column_name, type, { :default => default, :limit => limit })
    end
    
    def change_column(table_name, column_name, type, options = {}) #:nodoc:
      unless options.include?(:default) && !(options[:null] == false && options[:default].nil?)
        options[:default] = select_one("SHOW COLUMNS FROM #{table_name} LIKE '#{column_name}'")["default"]
      end
      
      change_column_sql = "ALTER TABLE #{table_name} CHANGE #{column_name} #{column_name} #{type_to_sql(type, options[:limit])}"
      add_column_options!(change_column_sql, options)
      execute(change_column_sql)
    end
    
    def rename_column(table_name, column_name, new_column_name) #:nodoc:
      current_type = select_one("SHOW COLUMNS FROM #{table_name} LIKE '#{column_name}'")["type"]
      execute "ALTER TABLE #{table_name} CHANGE #{column_name} #{new_column_name} #{current_type}"
    end
  end
end

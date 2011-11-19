require 'arjdbc/hsqldb/adapter'

module ArJdbc
  module H2
    include HSQLDB

    def self.jdbc_connection_class
      ::ActiveRecord::ConnectionAdapters::H2JdbcConnection
    end

    def adapter_name #:nodoc:
      'H2'
    end

    def self.arel2_visitors(config)
      v = HSQLDB.arel2_visitors(config)
      v.merge({}.tap {|v| %w(h2 jdbch2).each {|a| v[a] = ::Arel::Visitors::HSQLDB } })
    end

    def h2_adapter
      true
    end

    def tables
      @connection.tables(nil, h2_schema)
    end

    def columns(table_name, name=nil)
      @connection.columns_internal(table_name.to_s, name, h2_schema)
    end

    def change_column(table_name, column_name, type, options = {}) #:nodoc:
      execute "ALTER TABLE #{table_name} ALTER COLUMN #{column_name} #{type_to_sql(type, options[:limit])}"
      change_column_default(table_name, column_name, options[:default]) if options_include_default?(options)
      change_column_null(table_name, column_name, options[:null], options[:default]) if options.key?(:null)
    end

    private
    def change_column_null(table_name, column_name, null, default = nil)
      if !null && !default.nil?
        execute("UPDATE #{table_name} SET #{column_name}=#{quote(default)} WHERE #{column_name} IS NULL")
      end
      if null
        execute "ALTER TABLE #{table_name} ALTER COLUMN #{column_name} SET NULL"
      else
        execute "ALTER TABLE #{table_name} ALTER COLUMN #{column_name} SET NOT NULL"
      end
    end

    def h2_schema
      @config[:schema] || ''
    end
  end
end

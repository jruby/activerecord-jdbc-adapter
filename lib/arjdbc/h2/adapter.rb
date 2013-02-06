require 'arjdbc/hsqldb/adapter'

module ArJdbc
  module H2
    include HSQLDB

    def self.jdbc_connection_class
      ::ActiveRecord::ConnectionAdapters::H2JdbcConnection
    end

    def self.column_selector
      [ /\.h2\./i, lambda { |cfg, column| column.extend(::ArJdbc::H2::Column) } ]
    end
    
    module Column
      include HSQLDB::Column
      
      private
      
      def simplified_type(field_type)
        super
      end

      # Post process default value from JDBC into a Rails-friendly format (columns{-internal})
      def default_value(value)
        # H2 auto-generated key default value
        return nil if value =~ /^\(NEXT VALUE FOR/i
        super
      end
      
    end
    
    ADAPTER_NAME = 'H2' # :nodoc:
    
    def adapter_name # :nodoc:
      ADAPTER_NAME
    end

    def self.arel2_visitors(config)
      visitors = HSQLDB.arel2_visitors(config)
      visitors.merge({
        'h2' => ::Arel::Visitors::HSQLDB,
        'jdbch2' => ::Arel::Visitors::HSQLDB,
      })
    end
    
    # #deprecated
    def h2_adapter # :nodoc:
      true
    end

    def modify_types(types)
      super(types)
      types[:float][:limit] = 17
      types
    end
    
    def tables
      @connection.tables(nil, h2_schema)
    end

    def columns(table_name, name = nil)
      @connection.columns_internal(table_name.to_s, name, h2_schema)
    end

    def change_column(table_name, column_name, type, options = {}) #:nodoc:
      execute "ALTER TABLE #{table_name} ALTER COLUMN #{column_name} #{type_to_sql(type, options[:limit])}"
      change_column_default(table_name, column_name, options[:default]) if options_include_default?(options)
      change_column_null(table_name, column_name, options[:null], options[:default]) if options.key?(:null)
    end

    def current_schema
      execute('CALL SCHEMA()')[0].values[0]
    end
    
    def quote(value, column = nil) # :nodoc:
      case value
      when String
        if value.empty?
          "''"
        else
          super
        end
      else
        super
      end
    end
    
    # EXPLAIN support :
    
    def supports_explain?; true; end

    def explain(arel, binds = [])
      sql = "EXPLAIN #{to_sql(arel, binds)}"
      raw_result  = execute(sql, "EXPLAIN", binds)
      raw_result[0].values.join("\n") # [ "SELECT \n ..." ].to_s
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

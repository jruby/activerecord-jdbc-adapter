module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module SchemaStatements
        # Returns an array of table names defined in the database.
        def tables(name = nil)
          @connection.tables(nil, name)
        end

        # Returns an array of Column objects for the table specified by +table_name+.
        # See the concrete implementation for details on the expected parameter values.
        def columns(table_name)
          @connection.columns(table_name)
        end

        # Returns an array of view names defined in the database.
        # (to be implemented)
        def views
          []
        end

        def primary_keys(table_name)
          @connection.primary_keys(table_name)
        end
      end
    end
  end
end

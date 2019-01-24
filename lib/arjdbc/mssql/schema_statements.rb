module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module SchemaStatements

        NATIVE_DATABASE_TYPES = {
          primary_key:  'int NOT NULL IDENTITY(1,1) PRIMARY KEY',
          integer:      { name: 'int' }, # :limit => 4
          boolean:      { name: 'bit' },
          decimal:      { name: 'decimal' },
          float:        { name: 'float' },
          bigint:       { name: 'bigint' },
          real:         { name: 'real' },
          date:         { name: 'date' },
          time:         { name: 'time' },
          datetime:     { name: 'datetime' },
          timestamp:    { name: 'datetime' },
          string:       { name: 'nvarchar', limit: 4000 },
          # varchar:      { name: 'varchar' }, # limit: 8000
          text:         { name: 'nvarchar(max)' },
          text_basic:   { name: 'text' },
          # ntext:        { name: 'ntext' },
          char:         { name: 'char' },
          # nchar:        { name: 'nchar' },
          binary:       { name: 'image' }, # NOTE: :name => 'varbinary(max)'
          binary_basic: { name: 'binary' },
          uuid:         { name: 'uniqueidentifier' },
          money:        { name: 'money' },
          # :smallmoney => { :name => 'smallmoney' },
        }.freeze

        def native_database_types
          NATIVE_DATABASE_TYPES
        end

        # Returns an array of table names defined in the database.
        def tables(name = nil)
          @connection.tables(nil, name)
        end

        # Returns an array of Column objects for the table specified by +table_name+.
        # See the concrete implementation for details on the expected parameter values.
        # NOTE: This is ready, all implemented in the java part of adapter,
        # it uses MSSQLColumn, SqlTypeMetadata, etc.
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

        def current_database
          select_value 'SELECT DB_NAME()'
        end

        def use_database(database = nil)
          database ||= config[:database]
          execute "USE #{quote_database_name(database)}" unless database.blank?
        end

        def drop_database(name)
          current_db = current_database
          use_database('master') if current_db.to_s == name
          execute "DROP DATABASE #{quote_database_name(name)}"
        end

        def create_database(name, options = {})
          execute "CREATE DATABASE #{quote_database_name(name)}"
        end

        def recreate_database(name, options = {})
          drop_database(name)
          create_database(name, options)
        end

        private

        def quote_database_name(name)
          quote_name_part(name.to_s)
        end

        def quote_name_part(part)
          part =~ /^\[.*\]$/ ? part : "[#{part.gsub(']', ']]')}]"
        end
      end
    end
  end
end

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

        # Returns an array of indexes for the given table.
        def indexes(table_name, name = nil)
          @connection.indexes(table_name, name)
        end

        def primary_keys(table_name)
          @connection.primary_keys(table_name)
        end

        def charset
          select_value "SELECT SqlCharSetName = CAST(SERVERPROPERTY('SqlCharSetName') AS NVARCHAR(128))"
        end

        def collation
          select_value "SELECT Collation = CAST(SERVERPROPERTY('Collation') AS NVARCHAR(128))"
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
          # Only SQL Server 2016 onwards:
          # execute "DROP DATABASE IF EXISTS #{quote_database_name(name)}"
          execute "IF EXISTS(SELECT name FROM sys.databases WHERE name='#{name}') DROP DATABASE #{quote_database_name(name)}"
        end

        def create_database(name, options = {})
          execute "CREATE DATABASE #{quote_database_name(name)}"
        end

        def recreate_database(name, options = {})
          drop_database(name)
          create_database(name, options)
        end

        def remove_column(table_name, column_name, type = nil, options = {})
          raise ArgumentError.new('You must specify at least one column name.  Example: remove_column(:people, :first_name)') if column_name.is_a? Array
          remove_check_constraints(table_name, column_name)
          remove_default_constraint(table_name, column_name)
          remove_indexes(table_name, column_name)
          execute "ALTER TABLE #{quote_table_name(table_name)} DROP COLUMN #{quote_column_name(column_name)}"
        end

        def rename_table(table_name, new_table_name)
          execute "EXEC sp_rename '#{table_name}', '#{new_table_name}'"
          rename_table_indexes(table_name, new_table_name)
        end

        # This is the same as the abstract method
        def quote_table_name(name)
          quote_column_name(name)
        end

        # This overrides the abstract method to be specific to SQL Server.
        def quote_column_name(name)
          name = name.to_s.split('.')
          name.map! { |n| quote_name_part(n) } # "[#{name}]"
          name.join('.')
        end

        def quote_database_name(name)
          quote_name_part(name.to_s)
        end

        # @private these cannot specify a limit
        NO_LIMIT_TYPES = %w( text binary boolean date datetime )

        def type_to_sql(type, limit = nil, precision = nil, scale = nil)
          type_s = type.to_s
          # MSSQL's NVARCHAR(n | max) column supports either a number between 1 and
          # 4000, or the word "MAX", which corresponds to 2**30-1 UCS-2 characters.
          #
          # It does not accept NVARCHAR(1073741823) here, so we have to change it
          # to NVARCHAR(MAX), even though they are logically equivalent.
          #
          # See: http://msdn.microsoft.com/en-us/library/ms186939.aspx
          #
          if type_s == 'string' && limit == 1073741823
            'NVARCHAR(MAX)'
          elsif NO_LIMIT_TYPES.include?(type_s)
            super(type)
          elsif type_s == 'integer' || type_s == 'int'
            if limit.nil? || limit == 4
              'int'
            elsif limit == 2
              'smallint'
            elsif limit == 1
              'tinyint'
            else
              'bigint'
            end
          elsif type_s == 'uniqueidentifier'
            type_s
          else
            super
          end
        end


        private

        # Implements the quoting style for SQL Server
        def quote_name_part(part)
          part =~ /^\[.*\]$/ ? part : "[#{part.gsub(']', ']]')}]"
        end

        def remove_check_constraints(table_name, column_name)
          constraints = select_values "SELECT CONSTRAINT_NAME FROM INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE where TABLE_NAME = '#{quote_string(table_name)}' and COLUMN_NAME = '#{quote_string(column_name)}'", 'SCHEMA'
          constraints.each do |constraint|
            execute "ALTER TABLE #{quote_table_name(table_name)} DROP CONSTRAINT #{quote_column_name(constraint)}"
          end
        end

        def remove_default_constraint(table_name, column_name)
          # If their are foreign keys in this table, we could still get back a 2D array, so flatten just in case.
          execute_procedure(:sp_helpconstraint, table_name, 'nomsg').flatten.select do |row|
            row['constraint_type'] == "DEFAULT on column #{column_name}"
          end.each do |row|
            execute "ALTER TABLE #{quote_table_name(table_name)} DROP CONSTRAINT #{row['constraint_name']}"
          end
        end

        def remove_indexes(table_name, column_name)
          indexes(table_name).select { |index| index.columns.include?(column_name.to_s) }.each do |index|
            remove_index(table_name, name: index.name)
          end
        end

      end
    end
  end
end

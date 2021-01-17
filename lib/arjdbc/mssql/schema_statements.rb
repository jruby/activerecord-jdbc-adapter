module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module SchemaStatements

        NATIVE_DATABASE_TYPES = {
          # Logical Rails types to SQL Server types
          primary_key:   'int NOT NULL IDENTITY(1,1) PRIMARY KEY',
          integer:       { name: 'int', limit: 4 },
          boolean:       { name: 'bit' },
          decimal:       { name: 'decimal' },
          float:         { name: 'float' },
          date:          { name: 'date' },
          time:          { name: 'time' },
          datetime:      { name: 'datetime2' },
          string:        { name: 'nvarchar', limit: 4000 },
          text:          { name: 'nvarchar(max)' },
          binary:        { name: 'varbinary(max)' },
          # Other types or SQL Server specific
          bigint:        { name: 'bigint' },
          smalldatetime: { name: 'smalldatetime' },
          datetime_basic: { name: 'datetime' },
          timestamp:     { name: 'datetime' },
          real:          { name: 'real' },
          money:         { name: 'money' },
          smallmoney:    { name: 'smallmoney' },
          char:          { name: 'char' },
          nchar:         { name: 'nchar' },
          varchar:       { name: 'varchar', limit: 8000 },
          varchar_max:   { name: 'varchar(max)' },
          uuid:          { name: 'uniqueidentifier' },
          binary_basic:  { name: 'binary' },
          varbinary:     { name: 'varbinary', limit: 8000 },
          # Deprecated SQL Server types
          image:         { name: 'image' },
          ntext:         { name: 'ntext' },
          text_basic:    { name: 'text' }
        }.freeze

        def native_database_types
          NATIVE_DATABASE_TYPES
        end

        # Returns an array of table names defined in the database.
        def tables(name = nil)
          if name
            ActiveSupport::Deprecation.warn(<<-MSG.squish)
              Passing arguments to #tables is deprecated without replacement.
            MSG
          end

          @connection.tables(nil, name)
        end

        # Returns an array of Column objects for the table specified by +table_name+.
        # See the concrete implementation for details on the expected parameter values.
        # NOTE: This is ready, all implemented in the java part of adapter,
        # it uses MSSQLColumn, SqlTypeMetadata, etc.
        def columns(table_name)
          log('JDBC: GETCOLUMNS', 'SCHEMA') { @connection.columns(table_name) }
        rescue => e
          raise translate_exception_class(e, nil)
        end

        # Returns an array of view names defined in the database.
        # (to be implemented)
        def views
          []
        end

        def table_exists?(table_name)
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            #table_exists? currently checks both tables and views.
            This behavior is deprecated and will be changed with Rails 5.1 to only check tables.
            Use #data_source_exists? instead.
          MSG

          tables.include?(table_name.to_s)
        end

        # Returns an array of indexes for the given table.
        def indexes(table_name, name = nil)
          @connection.indexes(table_name, name)
        end

        def primary_keys(table_name)
          @connection.primary_keys(table_name)
        end

        def foreign_keys(table_name)
          @connection.foreign_keys(table_name)
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

        def drop_table(table_name, options = {})
          # mssql cannot recreate referenced table with force: :cascade
          # https://docs.microsoft.com/en-us/sql/t-sql/statements/drop-table-transact-sql?view=sql-server-2017
          if options[:force] == :cascade
            execute_procedure(:sp_fkeys, pktable_name: table_name).each do |fkdata|
              fktable = fkdata['FKTABLE_NAME']
              fkcolmn = fkdata['FKCOLUMN_NAME']
              pktable = fkdata['PKTABLE_NAME']
              pkcolmn = fkdata['PKCOLUMN_NAME']
              remove_foreign_key(fktable, name: fkdata['FK_NAME'])
              execute("DELETE FROM #{quote_table_name(fktable)} WHERE #{quote_column_name(fkcolmn)} IN ( SELECT #{quote_column_name(pkcolmn)} FROM #{quote_table_name(pktable)} )")
            end
          end

          if options[:if_exists] && @mssql_major_version < 13
            # this is for sql server 2012 and 2014
            execute "IF EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = #{quote(table_name)}) DROP TABLE #{quote_table_name(table_name)}"
          else
            # For sql server 2016 onwards
            super
          end
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
        NO_LIMIT_TYPES = %w(text binary boolean date)

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

        # SQL Server requires the ORDER BY columns in the select
        # list for distinct queries, and requires that the ORDER BY
        # include the distinct column.
        def columns_for_distinct(columns, orders) #:nodoc:
          order_columns = orders.reject(&:blank?).map{ |s|
              # Convert Arel node to string
              s = s.to_sql unless s.is_a?(String)
              # Remove any ASC/DESC modifiers
              s.gsub(/\s+(?:ASC|DESC)\b/i, '')
               .gsub(/\s+NULLS\s+(?:FIRST|LAST)\b/i, '')
            }.reject(&:blank?).map.with_index { |column, i| "#{column} AS alias_#{i}" }

          [super, *order_columns].join(', ')
        end

        def rename_column(table_name, column_name, new_column_name)
          # The below line checks if column exists otherwise raise activerecord
          # default exception for this case.
          _column = column_for(table_name, column_name)

          execute "EXEC sp_rename '#{table_name}.#{column_name}', '#{new_column_name}', 'COLUMN'"
          rename_column_indexes(table_name, column_name, new_column_name)
        end

        def change_column_default(table_name, column_name, default_or_changes)
          remove_default_constraint(table_name, column_name)

          default = extract_new_default_value(default_or_changes)
          unless default.nil?
            column = columns(table_name).find { |c| c.name.to_s == column_name.to_s }
            result = execute "ALTER TABLE #{quote_table_name(table_name)} ADD CONSTRAINT DF_#{table_name}_#{column_name} DEFAULT #{quote_default_expression(default, column)} FOR #{quote_column_name(column_name)}"
            result
          end
        end

        def change_column(table_name, column_name, type, options = {})
          column = columns(table_name).find { |c| c.name.to_s == column_name.to_s }

          indexes = []
          if options_include_default?(options) || (column && column.type != type.to_sym)
            remove_default_constraint(table_name, column_name)
            indexes = indexes(table_name).select{ |index| index.columns.include?(column_name.to_s) }
            remove_indexes(table_name, column_name)
          end

          if !options[:null].nil? && options[:null] == false && !options[:default].nil?
            execute "UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote_default_expression(options[:default], column)} WHERE #{quote_column_name(column_name)} IS NULL"
          end

          change_column_type(table_name, column_name, type, options)
          change_column_default(table_name, column_name, options[:default]) if options_include_default?(options)

          # add any removed indexes back
          indexes.each do |index|
            index_columns = index.columns.map { |c| quote_column_name(c) }.join(', ')
            execute "CREATE INDEX #{quote_table_name(index.name)} ON #{quote_table_name(table_name)} (#{index_columns})"
          end
        end

        def change_column_null(table_name, column_name, null, default = nil)
          column = column_for(table_name, column_name)
          quoted_table = quote_table_name(table_name)
          quoted_column = quote_column_name(column_name)
          quoted_default = quote(default)
          unless null || default.nil?
            execute("UPDATE #{quoted_table} SET #{quoted_column}=#{quoted_default} WHERE #{quoted_column} IS NULL")
          end
          sql_alter = [
            "ALTER TABLE #{quoted_table}",
            "ALTER COLUMN #{quoted_column} #{type_to_sql column.type, column.limit, column.precision, column.scale}",
            (' NOT NULL' unless null)
          ]

          execute(sql_alter.join(' '))
        end

        private

        def change_column_type(table_name, column_name, type, options = {})
          sql = "ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
          sql << (options[:null] ? " NULL" : " NOT NULL") if options.has_key?(:null)
          result = execute(sql)
          result
        end

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

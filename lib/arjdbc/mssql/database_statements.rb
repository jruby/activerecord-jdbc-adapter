module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module DatabaseStatements

        def exec_proc(proc_name, *variables)
          vars =
            if variables.any? && variables.first.is_a?(Hash)
              variables.first.map { |k, v| "@#{k} = #{quote(v)}" }
            else
              variables.map { |v| quote(v) }
            end.join(', ')
          sql = "EXEC #{proc_name} #{vars}".strip
          log(sql, 'Execute Procedure') do
            result = @connection.execute_query_raw(sql)
            result.map! do |row|
              row = row.is_a?(Hash) ? row.with_indifferent_access : row
              yield(row) if block_given?
              row
            end
            result
          end
        end
        alias_method :execute_procedure, :exec_proc # AR-SQLServer-Adapter naming

        def execute(sql, name = nil)
          # with identity insert on block
          if insert_sql?(sql)
            if id_insert_table_name = identity_insert_table_name(sql)
              with_identity_insert_enabled(id_insert_table_name) do
                super
              end
            else
              super
            end
          else
            super
          end
        end

        private

        def insert_sql?(sql)
          !(sql =~ /^\s*(INSERT|EXEC sp_executesql N'INSERT)/i).nil? 
        end

        def identity_insert_table_name(sql)
          table_name = ArJdbc::MSSQL::Utils.get_table_name(sql)
          id_column = identity_column_name(table_name)
          if id_column && sql.strip =~ /INSERT INTO [^ ]+ ?\((.+?)\)/i
            insert_columns = $1.split(/, */).map{|w| ArJdbc::MSSQL::Utils.unquote_column_name(w)}
            return table_name if insert_columns.include?(id_column)
          end
        end

        def identity_column_name(table_name)
          for column in columns(table_name)
            return column.name if column.identity
          end
          nil
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

      end
    end
  end
end

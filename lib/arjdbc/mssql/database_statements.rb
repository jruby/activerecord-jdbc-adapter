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
            table_name_for_identity_insert = identity_insert_table_name(sql)

            if table_name_for_identity_insert
              with_identity_insert_enabled(table_name_for_identity_insert) do
                super
              end
            else
              super
            end
          else
            super
          end
        end

        def exec_insert(sql, name = nil, binds = [], pk = nil, sequence_name = nil)
          table_name_for_identity_insert = identity_insert_table_name(sql)

          if table_name_for_identity_insert
            with_identity_insert_enabled(table_name_for_identity_insert) do
              super
            end
          else
            super
          end
        end

        # Implements the truncate method.
        def truncate(table_name, name = nil)
          execute "TRUNCATE TABLE #{quote_table_name(table_name)}", name
        end

        # Not a rails method, own method to test different isolation
        # levels supported by the mssql adapter.
        def supports_transaction_isolation_level?(level)
          @connection.supports_transaction_isolation?(level)
        end

        def transaction_isolation=(value)
          @connection.set_transaction_isolation(value)
        end

        def transaction_isolation
          @connection.get_transaction_isolation
        end

        private

        def insert_sql?(sql)
          !(sql =~ /^\s*(INSERT|EXEC sp_executesql N'INSERT)/i).nil? 
        end

        def identity_insert_table_name(sql)
          table_name = get_table_name(sql)
          id_column = identity_column_name(table_name)
          if id_column && sql.strip =~ /INSERT INTO [^ ]+ ?\((.+?)\)/i
            insert_columns = $1.split(/, */).map{|w| ArJdbc::MSSQL::Utils.unquote_column_name(w)}
            return table_name if insert_columns.include?(id_column)
          end
        end

        def identity_column_name(table_name)
          for column in schema_cache.columns(table_name)
            return column.name if column.identity?
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
          if enable
            execute("SET IDENTITY_INSERT #{quote_table_name(table_name)} ON")
          else
            execute("SET IDENTITY_INSERT #{quote_table_name(table_name)} OFF")
          end
        rescue Exception => e
          raise ActiveRecord::ActiveRecordError, "IDENTITY_INSERT could not be turned" +
                " #{enable ? 'ON' : 'OFF'} for table #{table_name} due : #{e.inspect}"
        end

        def get_table_name(sql, qualified = nil)
          if sql =~ TABLE_NAME_INSERT_UPDATE
            tn = $2 || $3
            qualified ? tn : ArJdbc::MSSQL::Utils.unqualify_table_name(tn)
          elsif sql =~ TABLE_NAME_FROM
            qualified ? $1 : ArJdbc::MSSQL::Utils.unqualify_table_name($1)
          else
            nil
          end
        end

        TABLE_NAME_INSERT_UPDATE = /^\s*(INSERT|EXEC sp_executesql N'INSERT)(?:\s+INTO)?\s+([^\(\s]+)\s*|^\s*update\s+([^\(\s]+)\s*/i

        TABLE_NAME_FROM = /\bFROM\s+([^\(\)\s,]+)\s*/i
      end
    end
  end
end

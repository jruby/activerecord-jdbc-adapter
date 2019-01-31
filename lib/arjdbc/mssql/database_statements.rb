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


      end
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      class SchemaCreation < AbstractAdapter::SchemaCreation
        private

        def visit_TableDefinition(o)
          if o.as
            table_name = quote_table_name(o.temporary ? "##{o.name}" : o.name)
            projections, source = @conn.to_sql(o.as).match(%r{SELECT\s+(.*)?\s+FROM\s+(.*)?}).captures
            select_into = "SELECT #{projections} INTO #{table_name} FROM #{source}"
          else
            o.instance_variable_set :@as, nil
            super
          end
        end

        # There is no RESTRICT in MSSQL but it has NO ACTION which behave
        # same as RESTRICT, added this behave according rails api.
        def action_sql(action, dependency)
          case dependency
          when :restrict then "ON #{action} NO ACTION"
          else
            super
          end
        end

      end
    end
  end
end

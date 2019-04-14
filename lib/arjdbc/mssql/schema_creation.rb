module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      class SchemaCreation < AbstractAdapter::SchemaCreation
        private

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

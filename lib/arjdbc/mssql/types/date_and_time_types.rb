# MSSQL date and time types definitions
module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module Type
        class Date < ActiveRecord::Type::Date
        end

        class DateTime < ActiveRecord::Type::DateTime
        end

        class SmallDateTime < DateTime
          def type
            :smalldatetime
          end
        end

        class Time < ActiveRecord::Type::Time
        end

      end
    end
  end
end


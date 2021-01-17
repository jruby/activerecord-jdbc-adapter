require 'arjdbc/mssql/types/numeric_types'
require 'arjdbc/mssql/types/string_types'
require 'arjdbc/mssql/types/binary_types'
require 'arjdbc/mssql/types/date_and_time_types'
require 'arjdbc/mssql/types/deprecated_types'

# MSSQL type definitions
module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module Type

        class Boolean < ActiveRecord::Type::Boolean
        end

        class UUID < ActiveRecord::Type::String
          ACCEPTABLE_UUID = %r{\A\{?([a-fA-F0-9]{4}-?){8}\}?\z}x

          def type
            :uuid
          end

          def type_cast(value)
            value.to_s[ACCEPTABLE_UUID, 0]
          end
        end

        class XML < ActiveRecord::Type::String
          def type
            :xml
          end

          def type_cast_for_database(value)
            return unless value
            Data.new(super)
          end

          class Data
            def initialize(value)
              @value = value
            end

            def to_s
              @value
            end
          end
        end

      end
    end
  end
end

# MSSQL binary types definitions
module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module Type

        class BinaryBasic < ActiveRecord::Type::Binary
          def type
            :binary_basic
          end
        end

        class Varbinary < ActiveRecord::Type::Binary
          def type
            :varbinary
          end
        end

        # This is the Rails binary type
        class VarbinaryMax < ActiveRecord::Type::Binary
          def type
            :binary
          end

          def limit
            @limit ||= 2_147_483_647
          end
        end

      end
    end
  end
end

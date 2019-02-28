# MSSQL deprecated type definitions
module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module Type

        class Text < ActiveRecord::Type::String
          def type
            :text_basic
          end

          def limit
            @limit ||= 2_147_483_647
          end
        end

        class Ntext < ActiveRecord::Type::String
          def type
            :ntext
          end

          def limit
            @limit ||= 2_147_483_647
          end
        end

        class Image < ActiveRecord::Type::Binary
          def type
            :image
          end

          def limit
            @limit ||= 2_147_483_647
          end
        end

      end
    end
  end
end

# MSSQL date and time types definitions
module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module Type
        class Date < ActiveRecord::Type::Date
        end


        # NOTE: The key here is to get usec in a format like ABC000 to get
        # minimal rounding issues. MSSQL has its own rounding strategy
        # (Rounded to increments of .000, .003, or .007 seconds)
        class DateTime < ActiveRecord::Type::DateTime
          private

          def cast_value(value)
            value = value.respond_to?(:usec) ? value : super
            return unless value

            value.change usec: cast_usec(value)
          end

          def cast_usec(value)
            return 0 unless value.respond_to?(:usec)

            return 0 if value.usec.zero?

            seconds = value.usec.to_f / 1_000_000.0
            second_precision = 0.00333
            ss_seconds = ((seconds * (1 / second_precision)).round / (1 / second_precision)).round(3)
            (ss_seconds * 1_000_000).to_i
          end
        end

        class SmallDateTime < DateTime

          # this type is still and logical rails datetime even though is
          # smalldatetime in MSSQL
          def type
            :datetime
          end

          private

          def cast_usec(_value)
            0
          end
        end

        class Time < ActiveRecord::Type::Time
        end

      end
    end
  end
end


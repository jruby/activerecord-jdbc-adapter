# MSSQL date and time types definitions
module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module Type
        class Date < ActiveRecord::Type::Date
        end

        class DateTime2 < ActiveRecord::Type::DateTime
          def type_cast_for_schema(value)
            return "'#{value}'" if value.acts_like?(:string)

            if value.usec > 0
              "'#{value.to_s(:db)}.#{value.usec.to_s.remove(/0+$/)}'"
            else
              "'#{value.to_s(:db)}'"
            end
          end

          # Overrides method in a super class (located in active model)
          def apply_seconds_precision(value)
            return value unless ar_precision && value.respond_to?(:usec)

            number_of_insignificant_digits = 6 - ar_precision
            round_power = 10**number_of_insignificant_digits
            value.change(usec: value.usec / round_power * round_power)
          end

          private

          def cast_value(value)
            value = super(value)
            apply_seconds_precision(value)
          end

          # Even though the mssql time precision is 7 we will ignore the
          # nano seconds precision, this adapter work with microseconds only.
          def ar_precision
            precision || 6
          end
        end

        # NOTE: The key here is to get usec in a format like ABC000 to get
        # minimal rounding issues. MSSQL has its own rounding strategy
        # (Rounded to increments of .000, .003, or .007 seconds)
        class DateTime < ActiveRecord::Type::DateTime
          def type
            :datetime_basic
          end

          def type_cast_for_schema(value)
            return "'#{value}'" if value.acts_like?(:string)

            if value.usec > 0
              "'#{value.to_s(:db)}.#{value.usec.to_s.remove(/0+$/)}'"
            else
              "'#{value.to_s(:db)}'"
            end
          end

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

          # To be mapped properly in schema.rb it needs to be smalldatetime.
          def type
            :smalldatetime
          end

          private

          def cast_usec(_value)
            0
          end
        end

        class Time < ActiveRecord::Type::Time
          def type_cast_for_schema(value)
            return "'#{value}'" if value.acts_like?(:string)

            if value.usec > 0
              "'#{value.to_s(:db)}.#{value.usec.to_s.remove(/0+$/)}'"
            else
              "'#{value.to_s(:db)}'"
            end
          end

          # Overrides method in a super class (located in active model)
          def apply_seconds_precision(value)
            return value unless ar_precision && value.respond_to?(:usec)

            number_of_insignificant_digits = 6 - ar_precision
            round_power = 10**number_of_insignificant_digits
            value.change(usec: value.usec / round_power * round_power)
          end

          private

          def cast_value(value)
            value = super(value)
            apply_seconds_precision(value)
          end

          # Even though the mssql time precision is 7 we will ignore the
          # nano seconds precision, this adapter work with microseconds only.
          def ar_precision
            precision || 6
          end
        end

      end
    end
  end
end


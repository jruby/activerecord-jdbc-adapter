module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module Quoting
        # Quote date/time values for use in SQL input, includes microseconds
        # with three digits only if the value is a Time responding to usec.
        # The JDBC drivers does not work with 6 digits microseconds
        def quoted_date(value)
          if value.acts_like?(:time)
            value = time_with_db_timezone(value)
          end

          result = value.to_s(:db)

          if value.respond_to?(:usec) && value.usec > 0
            "#{result}.#{sprintf("%06d", value.usec)}"
          else
            result
          end
        end

        # Quotes strings for use in SQL input.
        def quote_string(s)
          s.to_s.gsub(/\'/, "''")
        end

        # Does not quote function default values for UUID columns
        def quote_default_expression(value, column)
          cast_type = lookup_cast_type(column.sql_type)
          if cast_type.type == :uuid && value =~ /\(\)/
            value
          else
            super
          end
        end

        def quoted_true
          1
        end

        def quoted_false
          0
        end

        # @override
        def quoted_time(value)
          if value.acts_like?(:time)
            tz_value = time_with_db_timezone(value)
            usec = value.respond_to?(:usec) ? value.usec : 0
            sprintf('%02d:%02d:%02d.%06d', tz_value.hour, tz_value.min, tz_value.sec, usec)
          else
            quoted_date(value)
          end
        end

        # @private
        # @see #quote in old adapter
        BLOB_VALUE_MARKER = "''"

        private

        def time_with_db_timezone(value)
          zone_conv_method = if ActiveRecord::Base.default_timezone == :utc
                               :getutc
                             else
                               :getlocal
                             end

          if value.respond_to?(zone_conv_method)
            value = value.send(zone_conv_method)
          else
            value
          end
        end

        # @override
        # FIXME: it need to be improved to handle other custom types.
        # Also check if it's possible insert integer into a NVARCHAR
        def _quote(value)
          case value
          when ActiveRecord::Type::Binary::Data
            "0x#{value.hex}"
          # when SomeOtherBinaryData then BLOB_VALUE_MARKER
          # when SomeOtherData then "yyy"
          when String, ActiveSupport::Multibyte::Chars
            "N'#{quote_string(value)}'"
          # when OnlyTimeType then "'#{quoted_time(value)}'"
          when Date, Time
            "'#{quoted_date(value)}'"
          when TrueClass
            quoted_true
          when FalseClass
            quoted_false
          else
            super
          end
        end
      end
    end
  end
end

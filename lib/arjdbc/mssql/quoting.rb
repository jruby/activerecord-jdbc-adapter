module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module Quoting
        # Quote date/time values for use in SQL input, includes microseconds
        # with three digits only if the value is a Time responding to usec.
        # The JDBC drivers does not work with 6 digits microseconds
        def quoted_date(value)
          if value.acts_like?(:time)
            zone_conv_method = if ActiveRecord::Base.default_timezone == :utc
                                 :getutc
                               else
                                 :getlocal
                               end

            if value.respond_to?(zone_conv_method)
              value = value.send(zone_conv_method)
            end
          end

          result = value.to_s(:db)
          if value.respond_to?(:usec) && value.usec > 0
            "#{result}.#{sprintf("%03d", value.usec / 1000)}"
          else
            result
          end
        end

        # Quotes strings for use in SQL input.
        def quote_string(s)
          s.to_s.gsub /\'/, "''"
        end

        # @override
        def quoted_time(value)
          if value.acts_like?(:time)
            tz_value = get_time(value)
            usec = value.respond_to?(:usec) ? (value.usec / 1000) : 0
            sprintf('%02d:%02d:%02d.%03d', tz_value.hour, tz_value.min, tz_value.sec, usec)
          else
            quoted_date(value)
          end
        end

        # @private
        # @see #quote in old adapter
        BLOB_VALUE_MARKER = "''"

        private

        # @override
        # FIXME: it need to be improved to handle other custom types.
        # Also check if it's possible insert integer into a NVARCHAR
        def _quote(value)
          case value
          # when SomeBinaryData then "xxx"
          # when SomeOtherBinaryData then BLOB_VALUE_MARKER
          # when SomeOtherData then "yyy"
          when String, ActiveSupport::Multibyte::Chars then
            "N'#{quote_string(value)}'"
          # when OnlyTimeType then "'#{quoted_time(value)}'"
          when Date, Time then "'#{quoted_date(value)}'"
          when TrueClass then '1'
          when FalseClass then '0'
          else
            super
          end
        end
      end
    end
  end
end

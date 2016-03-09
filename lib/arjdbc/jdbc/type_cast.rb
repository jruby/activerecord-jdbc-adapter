require 'active_record/connection_adapters/column'

module ActiveRecord::ConnectionAdapters
  module Jdbc
    # Type casting methods taken from AR 4.1's Column class.
    # @private Simply to quickly "hack-in" 4.2 compatibility.
    module TypeCast

      TRUE_VALUES = Column::TRUE_VALUES if Column.const_defined?(:TRUE_VALUES)
      FALSE_VALUES = Column.const_defined?(:FALSE_VALUES) ? Column::FALSE_VALUES : ActiveModel::Type::Boolean::FALSE_VALUES

      #module Format
      ISO_DATE = Column::Format::ISO_DATE
      ISO_DATETIME = Column::Format::ISO_DATETIME
      #end

      # Used to convert from BLOBs to Strings
      def binary_to_string(value)
        value
      end

      def value_to_date(value)
        if value.is_a?(String)
          return nil if value.empty?
          fast_string_to_date(value) || fallback_string_to_date(value)
        elsif value.respond_to?(:to_date)
          value.to_date
        else
          value
        end
      end

      def string_to_time(string)
        return string unless string.is_a?(String)
        return nil if string.empty?
        return string if string =~ /^-?infinity$/.freeze

        fast_string_to_time(string) || fallback_string_to_time(string)
      end

      def string_to_dummy_time(string)
        return string unless string.is_a?(String)
        return nil if string.empty?

        dummy_time_string = "2000-01-01 #{string}"

        fast_string_to_time(dummy_time_string) || begin
          time_hash = Date._parse(dummy_time_string)
          return nil if time_hash[:hour].nil?
          new_time(*time_hash.values_at(:year, :mon, :mday, :hour, :min, :sec, :sec_fraction))
        end
      end

      # convert something to a boolean
      def value_to_boolean(value)
        if value.is_a?(String) && value.empty?
          nil
        else
          TRUE_VALUES.include?(value)
        end
      end if const_defined?(:TRUE_VALUES) # removed on AR 5.0

      # convert something to a boolean
      def value_to_boolean(value)
        if value.is_a?(String) && value.empty?
          nil
        else
          ! FALSE_VALUES.include?(value)
        end
      end unless const_defined?(:TRUE_VALUES)

      # Used to convert values to integer.
      # handle the case when an integer column is used to store boolean values
      def value_to_integer(value)
        case value
        when TrueClass, FalseClass
          value ? 1 : 0
        else
          value.to_i rescue nil
        end
      end

      # convert something to a BigDecimal
      def value_to_decimal(value)
        # Using .class is faster than .is_a? and
        # subclasses of BigDecimal will be handled
        # in the else clause
        if value.class == BigDecimal
          value
        elsif value.respond_to?(:to_d)
          value.to_d
        else
          value.to_s.to_d
        end
      end

      protected
        # '0.123456' -> 123456
        # '1.123456' -> 123456
        def microseconds(time)
          time[:sec_fraction] ? (time[:sec_fraction] * 1_000_000).to_i : 0
        end

        def new_date(year, mon, mday)
          if year && year != 0
            Date.new(year, mon, mday) rescue nil
          end
        end

        def new_time(year, mon, mday, hour, min, sec, microsec, offset = nil)
          # Treat 0000-00-00 00:00:00 as nil.
          return nil if year.nil? || (year == 0 && mon == 0 && mday == 0)

          if offset
            time = Time.utc(year, mon, mday, hour, min, sec, microsec) rescue nil
            return nil unless time

            time -= offset
            ActiveRecord::Base.default_timezone == :utc ? time : time.getlocal
          else
            timezone = ActiveRecord::Base.default_timezone
            Time.public_send(timezone, year, mon, mday, hour, min, sec, microsec) rescue nil
          end
        end

        def fast_string_to_date(string)
          if string =~ ISO_DATE
            new_date $1.to_i, $2.to_i, $3.to_i
          end
        end

        # Doesn't handle time zones.
        def fast_string_to_time(string)
          if string =~ ISO_DATETIME
            microsec = ($7.to_r * 1_000_000).to_i
            new_time $1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i, microsec
          end
        end

        def fallback_string_to_date(string)
          new_date(*::Date._parse(string, false).values_at(:year, :mon, :mday))
        end

        def fallback_string_to_time(string)
          time_hash = Date._parse(string)
          time_hash[:sec_fraction] = microseconds(time_hash)
          time_hash[:year] *= -1 if time_hash[:zone] == 'BC'

          new_time(*time_hash.values_at(:year, :mon, :mday, :hour, :min, :sec, :sec_fraction, :offset))
        end

    end
  end
end

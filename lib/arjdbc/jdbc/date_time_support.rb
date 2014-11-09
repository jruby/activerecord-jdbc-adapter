module ArJdbc
  module DateTimeSupport

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

      def string_to_time(value)
        if value =~ ActiveRecord::ConnectionAdapters::Column::Format::ISO_DATETIME
          microsec = ($7.to_r * 1_000_000).to_i
          new_time $1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i, microsec
        end
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

      def string_to_date(value)
        if value.is_a?(String)
          return nil if value.empty?
          fast_string_to_date(value) || fallback_string_to_date(value)
        elsif value.respond_to?(:to_date)
          value.to_date
        else
          value
        end
      end

      def new_time(year, mon, mday, hour, min, sec, microsec, offset = nil)
        # Treat 0000-00-00 00:00:00 as nil.
        return if year.nil? || (year == 0 && mon == 0 && mday == 0)

        if offset
          time = ::Time.utc(year, mon, mday, hour, min, sec, microsec) rescue nil
          return unless time

          time -= offset
          Base.default_timezone == :utc ? time : time.getlocal
        else
          ::Time.public_send(Base.default_timezone, year, mon, mday, hour, min, sec, microsec) rescue nil
        end
      end

      def fast_string_to_date(string)
        if string =~ ActiveRecord::ConnectionAdapters::Column::Format::ISO_DATE
          new_date $1.to_i, $2.to_i, $3.to_i
        end
      end

      def fallback_string_to_date(string)
        new_date(*::Date._parse(string, false).values_at(:year, :mon, :mday))
      end

      def new_date(year, mon, mday)
        if year && year != 0
          Date.new(year, mon, mday) rescue nil
        end
      end

      # Doesn't handle time zones.
      def fast_string_to_time(string)
        if string =~ ActiveRecord::ConnectionAdapters::Column::Format::ISO_DATETIME
          microsec = ($7.to_r * 1_000_000).to_i
          new_time $1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i, microsec
        end
      end
    end
  end
end

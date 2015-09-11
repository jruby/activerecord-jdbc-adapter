  ActiveRecord::ConnectionAdapters::PostgreSQL::OID::DateTime.class_eval do
    def cast_value(value)
      if value.is_a?(::String)
        case value
        when 'infinity' then ::Float::INFINITY
        when '-infinity' then -::Float::INFINITY
        #when / BC$/
        #  astronomical_year = format("%04d", value[/^\d+/].to_i)
        #  super(value.sub(/ BC$/, "").sub(/^\d+/, astronomical_year))
        else
          if value.end_with?(' BC')
            DateTime.parse("-#{value}"[0...-3])
          else
            super
          end
        end
      else
        value
      end
    end
  end
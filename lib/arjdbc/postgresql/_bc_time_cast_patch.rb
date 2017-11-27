ActiveRecord::ConnectionAdapters::PostgreSQL::OID::DateTime.class_eval do
  def cast_value(value)
    return value unless value.is_a?(::String)

    case value
      when 'infinity' then ::Float::INFINITY
      when '-infinity' then -::Float::INFINITY
      # when / BC$/
      #   astronomical_year = format("%04d", -value[/^\d+/].to_i + 1)
      #   super(value.sub(/ BC$/, "").sub(/^\d+/, astronomical_year))
      # else
      #   super
      else
        if value.end_with?(' BC')
          astronomical_year = format("%04d", -value[/^\d+/].to_i + 1)
          DateTime.parse("#{value}"[0...-3].sub(/^\d+/, astronomical_year))
        else
          super
        end
    end
  end

  def apply_seconds_precision(value); value end
end
# frozen_string_literal: false

require File.expand_path('record', File.dirname(__FILE__))

fields = {
    'a_binary' => Random.new.bytes(1024) + Random.new.bytes(512),
    'a_boolean' => true,
    'a_date' => Date.today,
    'a_datetime' => Time.now.to_datetime,
    'a_decimal' => BigDecimal('1234567890.55555'),
    'a_float' => 999.99,
    'a_integer' => 4242,
    'a_string' => 'BORAT Ipsum!',
    'a_text' => 'Kazakhstan is the greatest country in the world. ' <<
        'All other countries are run by little girls. ' <<
        'Kazakhstan is number one exporter of potassium. ' <<
        'Other Central Asian countries have inferior potassium. ' <<
        'Kazakhstan is the greatest country in the world. ' <<
        'All other countries is the home of the gays.' <<
        "\n\n" <<
        'In Kazakhstan, it is illegal for more than five woman to be in ' <<
        'the same place except for in brothel or in grave. ' <<
        'In US and A, many womens meet in a groups called feminists.',
    'a_time' => Time.now.to_time,
    'a_timestamp' => Time.now
}

empty = {}

Benchmark.ips do |x|
  x.config(:suite => BenchTestHelper::Suite::INSTANCE)

  record = BenchRecord.create.reload
  x.report("BenchRecord#update()") do
    record.update empty
  end

  fields.each do |field, value|
    label = value
    label = "#{value[0,16]}...(#{value.size})" if value.is_a?(String) && value.size > 16
    record = BenchRecord.create.reload
    x.report("BenchRecord#update('#{field}' => #{label.inspect})") do
      record.update(field => value)
    end
  end

  x.report("BenchRecord#update(...)") do
    record.update(fields)
  end

end

puts "\n"

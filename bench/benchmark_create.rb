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
    'a_string' => 'BORAT Ipsum!' * 2,
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

Benchmark.ips do |x|
  x.config(:suite => BenchTestHelper::Suite::INSTANCE)

  x.report("BenchRecord.create()") do
    BenchRecord.create()
  end

  fields.each do |field, value|
    label = value
    label = "#{value[0,16]}...(#{value.size})" if value.is_a?(String) && value.size > 16
    x.report("BenchRecord.create('#{field}' => #{label.inspect})") do
      BenchRecord.create!(field => value)
    end
  end

  x.report("BenchRecord.create(...)") do
    BenchRecord.create!(fields.dup)
  end

end

puts "\n"

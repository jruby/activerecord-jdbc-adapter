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

record_1 = BenchRecord.create.reload
record_2 = BenchRecord.create.reload
record_3 = BenchRecord.create.reload
def record_3.changed_attribute_names_to_save; attribute_names end # will always update all attributes

Benchmark.ips do |x|
  x.config(:suite => BenchTestHelper::Suite::INSTANCE)

  x.report("BenchRecord#update() [NOOP]") do
    record_1.update! empty # base-line expected to be a no-op
  end

  fields.each do |field, value|
    label = value
    label = "#{value[0,16]}...(#{value.size})" if value.is_a?(String) && value.size > 16
    x.report("BenchRecord#update('#{field}' => #{label.inspect})") do
      record_2.send "#{field}_will_change!" # forces the change even if the value did not change
      record_2.update!(field => value)
    end
  end

  x.report("BenchRecord#update(...)") do
    record_3.update!(fields)
  end

end

puts "\n"

require File.expand_path('record', File.dirname(__FILE__))

fields = {
  'a_binary' => Random.new.bytes(1024) + Random.new.bytes(512),
  'a_boolean' => true,
  'a_date' => Date.today,
  'a_datetime' => Time.now.to_datetime,
  'a_decimal' => BigDecimal.new('1234567890.55555'),
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

records = []; TIMES.times { records << BenchRecord.create.reload }

Benchmark.bmbm do |x|

  x.report("BenchRecord#update() [#{TIMES}x]") do
    TIMES.times do |i|
      records[i].update_attributes empty
    end
  end

  fields.each do |field, value|
    label = value
    label = "#{value[0,16]}...(#{value.size})" if value.is_a?(String) && value.size > 16
    attrs = Hash.new; attrs[field] = value
    x.report("BenchRecord#update('#{field}' => #{label.inspect}) [#{TIMES}x]") do
      # attrs = Hash.new; attrs[field] = value
      TIMES.times do |i|
        records[i].update_attributes(attrs)
      end
    end
  end

  attrs = fields
  x.report("BenchRecord#update(...) [#{TIMES}x]") do
    # attrs = fields.dup
    TIMES.times do |i|
      records[i].update_attributes(attrs)
    end
  end

end

puts "\n"
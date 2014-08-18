require File.expand_path('record', File.dirname(__FILE__))

BenchTestHelper.generate_records

selects = [
  'a_binary',
  'a_boolean',
  'a_date',
  'a_datetime',
  'a_decimal',
  'a_float',
  'a_integer',
  'a_string',
  'a_text',
  'a_time',
  'a_timestamp',
  '*'
]

Benchmark.bmbm do |x|

  total = BenchRecord.count

  selects.each do |select|
    x.report("BenchRecord.select('#{select}').where(:id => i).first [#{TIMES}x]") do
      TIMES.times do |i|
        BenchRecord.select(select).where(:id => i % total).first
      end
    end
  end

end

puts "\n"
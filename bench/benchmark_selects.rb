require File.expand_path('record', File.dirname(__FILE__))

do_yield "BenchRecord.create!(...) [#{DATA_SIZE}x]" do
  DATA_SIZE.times do |i|
    BenchRecord.create!({
      :id => i,
      :a_binary => '01' * 500,
      :a_boolean => true,
      :a_date => Date.today,
      :a_datetime => now = Time.now,
      :a_decimal => BigDecimal.new('10000000000.1'),
      :a_float => 100.001,
      :a_integer => 1000,
      :a_string => 'Glorious Nation of Kazakhstan',
      :a_text => 'This CJ was like no Kazakh woman I have ever seen. ' <<
                 'She had golden hairs, teeth as white as pearls, and the ' <<
                 'asshole of a seven-year-old. ' <<
                 'For the first time in my lifes, I was in love.',
      :a_time => now,
      :a_timestamp => now
    })
  end
end

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

  limit = ENV['LIMIT'] || DATA_SIZE

  x.report("BenchRecord.limit(#{limit}).load [#{TIMES}x]") do
    TIMES.times do
      BenchRecord.limit(limit).load
    end
  end

end

puts "\n"
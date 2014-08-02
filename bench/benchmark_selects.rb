require File.expand_path('record', File.dirname(__FILE__))

do_yield "BenchRecord.create!(...) [#{DATA_SIZE}x]" do
  DATA_SIZE.times do |i|
    BenchRecord.create!({
      :id => i,
      :a_binary => Random.new.bytes(1024),
      :a_boolean => true,
      :a_date => Date.today,
      :a_datetime => Time.now,
      :a_decimal => BigDecimal.new('18202824.2345'),
      :a_float => 829.8203749235,
      :a_integer => 4242,
      :a_string => 'Hello, Goodbye',
      :a_text => 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Cras commodo, mauris eu pulvinar porta, nunc est fringilla lorem, sit amet mattis massa libero id tellus. Praesent pretium, turpis et vestibulum accumsan, eros turpis rutrum diam, a elementum magna mi ut nisi. Sed sed porttitor urna, sed fringilla lectus. Nunc aliquam, arcu et vulputate vulputate, turpis massa auctor sem, in venenatis ligula tellus ut mi. Aenean pulvinar ligula tellus, vel commodo augue cursus a. In dictum diam ut ligula placerat, eget faucibus augue fermentum. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Suspendisse eget ligula in turpis vulputate eleifend eu et felis. Nam nec mattis lorem.',
      :a_time => Time.now,
      :a_timestamp => Time.now
    })
  end
end

selects = [
  #'*',
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

#  selects.each do |select|
#    x.report("30x SELECT #{select}, 5000 records") do
#      30.times do |i|
#        Product.select(select).to_a
#      end
#    end
#  end

end

puts "\n"
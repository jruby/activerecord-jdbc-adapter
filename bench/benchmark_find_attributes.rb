require File.expand_path('record', File.dirname(__FILE__))

BenchTestHelper.generate_records

BenchTestHelper.gc

Benchmark.ips do |x|

  an_id = BenchRecord.last.id

  x.report("BenchRecord.find( an_id ) [#{TIMES}x]") do
    TIMES.times do
      BenchRecord.find( an_id )
    end
  end

  x.report("BenchRecord.find( an_id ).attributes [#{TIMES}x]") do
    TIMES.times do
      BenchRecord.find( an_id ).attributes
    end
  end

end

puts "\n"

require File.expand_path('record', File.dirname(__FILE__))

BenchTestHelper.generate_records

BenchTestHelper.gc

Benchmark.bmbm do |x|

  total = BenchRecord.count

  x.report("BenchRecord.first(10) [#{TIMES}x]") do
    TIMES.times do
      BenchRecord.first(10)
    end
  end

  x.report("BenchRecord.last(100) [#{TIMES}x]") do
    TIMES.times do
      BenchRecord.last(100)
    end
  end

  x.report("BenchRecord.limit(100).load [#{TIMES}x]") do
    TIMES.times do
      BenchRecord.limit(100).load
    end
  end

end

puts "\n"

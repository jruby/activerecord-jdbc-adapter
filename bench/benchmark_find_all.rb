require File.expand_path('record', File.dirname(__FILE__))

BenchTestHelper.generate_records

BenchTestHelper.gc

Benchmark.ips do |x|
  x.config(:suite => BenchTestHelper::Suite::INSTANCE)

  total = BenchRecord.count

  x.report("BenchRecord.first(10)") do
    BenchRecord.first(10)
  end

  x.report("BenchRecord.last(100)") do
    BenchRecord.last(100)
  end

  x.report("BenchRecord.limit(100).load") do
    BenchRecord.limit(100).load
  end

end

puts "\n"

require File.expand_path('record', File.dirname(__FILE__))

BenchTestHelper.generate_records

BenchTestHelper.gc

Benchmark.ips do |x|
  x.config(:suite => BenchTestHelper::Suite::INSTANCE)

  an_id = BenchRecord.last.id

  x.report("BenchRecord.find(an_id)") do
    BenchRecord.find( an_id )
  end

  x.report("BenchRecord.find(an_id).attributes") do
    BenchRecord.find( an_id ).attributes
  end

end

puts "\n"

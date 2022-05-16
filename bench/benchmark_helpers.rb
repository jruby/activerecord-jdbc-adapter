require File.expand_path('setup', File.dirname(__FILE__))

Benchmark.ips do |x|
  x.config(:suite => BenchTestHelper::Suite::INSTANCE)

  x.report("ActiveRecord::ConnectionAdapters::Column.string_to_time") do
    ActiveRecord::ConnectionAdapters::Column.string_to_time("Wed, 04 Sep 2013 03:00:00 EAT")
  end
end

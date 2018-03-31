require File.expand_path('setup', File.dirname(__FILE__))

Benchmark.bmbm do |x|
  x.report("ActiveRecord::ConnectionAdapters::Column.string_to_time [#{TIMES}x]") do
    TIMES.times do
      ActiveRecord::ConnectionAdapters::Column.string_to_time("Wed, 04 Sep 2013 03:00:00 EAT")
    end
  end
end
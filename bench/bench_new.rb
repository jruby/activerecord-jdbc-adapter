require File.dirname(__FILE__) + '/bench_model'

puts "Widget.new"
Benchmark.bm do |make|
  TIMES.times do
    make.report do
      100_000.times do
        Widget.new
      end
    end
  end
end

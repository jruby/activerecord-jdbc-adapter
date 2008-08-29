require File.dirname(__FILE__) + '/bench_model'

puts "Widget.find(:first).attributes"
Benchmark.bm do |make|
  TIMES.times do
    w = Widget.find(:first)
    make.report do
      10_000.times do
        w.attributes # rails makes copy for every call
      end
    end
  end
end

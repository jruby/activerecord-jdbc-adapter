require File.dirname(__FILE__) + '/bench_model'

TIMES = (ARGV[0] || 5).to_i
Benchmark.bm do |make|
  TIMES.times do
    make.report do
      10_000.times do
        Widget.find(:all)
      end
    end
  end
end

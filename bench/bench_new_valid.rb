require File.dirname(__FILE__) + '/bench_model'

TIMES = (ARGV[0] || 5).to_i
Benchmark.bm(30) do |make|
  TIMES.times do
    make.report("Widget.new.valid?") do
      100_000.times do
        Widget.new.valid?
      end
    end
  end
end

require File.dirname(__FILE__) + '/bench_model'

TIMES = (ARGV[0] || 5).to_i
Benchmark.bm(30) do |make|
  TIMES.times do
    make.report("Widget.new.valid?") do
      widget = Widget.new
      100_000.times do
        widget.valid?
      end
    end
  end
end

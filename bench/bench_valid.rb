require File.dirname(__FILE__) + '/bench_model'

puts "Widget.new.valid?"
Benchmark.bm do |make|
  TIMES.times do
    make.report do
      widget = Widget.new
      100_000.times do
        widget.valid?
      end
    end
  end
end

require File.dirname(__FILE__) + '/bench_model'

puts "w = Widget.find(:first); Widget.new(w.attributes)"
Benchmark.bm do |make|
  TIMES.times do
    w = Widget.find(:first)
    params = w.attributes
    make.report do
      10_000.times do
        Widget.new(params)
      end
    end
  end
end

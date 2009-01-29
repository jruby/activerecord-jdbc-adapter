require File.dirname(__FILE__) + '/bench_model'

puts "Widget.new.valid?"
Benchmark.bm do |make|
  TIMES.times do
    make.report do
      1_000.times do
        Widget.create!(:name => "bench", :description => "Bench record")
      end
    end
  end
end

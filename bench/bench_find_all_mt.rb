require File.dirname(__FILE__) + '/bench_model'

Benchmark.bm do |make|
  TIMES.times do
    make.report do
      thrs = []
      errs = 0
      10.times do
        thrs << Thread.new do
          1000.times do
            begin
              Widget.find(:all)
            rescue Exception => e
              errs += 1
              Widget.logger.warn e.to_s
            end
          end
          Widget.clear_active_connections!
        end
      end
      thrs.each {|t| t.join}
      puts "errors: #{errs}" if errs > 0
    end
  end
end

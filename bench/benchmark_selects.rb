# frozen_string_literal: true

require File.expand_path('record', File.dirname(__FILE__))

BenchTestHelper.generate_records

selects = [
    'a_binary',
    'a_boolean',
    'a_date',
    'a_datetime',
    'a_decimal',
    'a_float',
    'a_integer',
    'a_string',
    'a_text',
    'a_time',
    'a_timestamp',
    '*'
]

Benchmark.ips do |x|

  total = BenchRecord.count
  an_id = BenchRecord.last.id

  selects.each do |select|
    x.report("BenchRecord.select('#{select}').where(id: i).first [#{TIMES}x]") do
      TIMES.times do |i|
        BenchRecord.select(select).where(id: i % total).first
      end
    end
  end

  selects.each do |select|
    x.report("BenchRecord.select('#{select}').where(['id = ?', an_id]).first [#{TIMES}x]") do
      TIMES.times do
        BenchRecord.select(select).where(['id = ?', an_id]).first
      end
    end
  end

end

puts "\n"

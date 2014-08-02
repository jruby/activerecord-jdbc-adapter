require File.expand_path('setup', File.dirname(__FILE__))

def do_yield(info)
  start = Time.now; outcome = yield
  puts " - #{info} took #{Time.now - start}"
  outcome
end

class BenchRecord < ActiveRecord::Base
end

do_yield 'BenchRecord.connection.drop_table(:bench_records)' do
  BenchRecord.connection.drop_table(:bench_records)
end if ActiveRecord::Base.connection.table_exists?(:bench_records)

do_yield 'BenchRecord.connection.create_table(:bench_records) { ... }' do
  BenchRecord.connection.create_table(:bench_records) do |t|
    t.binary :a_binary
    t.boolean :a_boolean
    t.date :a_date
    t.datetime :a_datetime
    t.decimal :a_decimal, :precision => 12, :scale => 4
    t.float :a_float
    t.integer :a_integer
    t.string :a_string
    t.text :a_text
    t.time :a_time
    t.timestamp :a_timestamp
  end
end

puts "\n"
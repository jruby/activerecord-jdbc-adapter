require File.expand_path('setup', File.dirname(__FILE__))

class BenchRecord < ActiveRecord::Base
end

BenchTestHelper.do_yield 'BenchRecord.connection.drop_table(:bench_records)' do
  BenchRecord.connection.drop_table(:bench_records)
end if ActiveRecord::Base.connection.table_exists?(:bench_records)

BenchTestHelper.do_yield 'BenchRecord.connection.create_table(:bench_records) { ... }' do
  BenchRecord.connection.create_table(:bench_records) do |t|
    t.binary :a_binary
    t.boolean :a_boolean
    t.date :a_date
    t.datetime :a_datetime
    t.decimal :a_decimal, :precision => 16, :scale => 5
    t.float :a_float
    t.integer :a_integer
    t.string :a_string
    t.text :a_text
    t.time :a_time
    t.timestamp :a_timestamp
  end
end

puts "\n"
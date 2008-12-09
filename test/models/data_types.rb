require 'rubygems'
require 'active_record'

class DbTypeMigration < ActiveRecord::Migration
  def self.up
    create_table "db_types", :force => true do |t|
      t.column :sample_timestamp, :timestamp
      t.column :sample_datetime, :datetime
      t.column :sample_date, :date
      t.column :sample_time, :time
      t.column :sample_decimal, :decimal, :precision => 15, :scale => 0
      t.column :sample_small_decimal, :decimal, :precision => 3, :scale => 2
      t.column :sample_binary, :binary
    end
  end

  def self.down
    drop_table "db_types"
  end
end

class DbType < ActiveRecord::Base
end

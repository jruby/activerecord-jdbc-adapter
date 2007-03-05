require 'jdbc_adapter'
require 'rubygems'
require 'active_record'

class DbTypeMigration < ActiveRecord::Migration
  def self.up
    create_table "db_types", :force => true do |t|
      t.column :sample_timestamp, :timestamp
      t.column :sample_decimal, :decimal, :precision=> 15, :scale => 0
    end
  end

  def self.down
    drop_table "db_types"
  end
end

class DbType < ActiveRecord::Base
end
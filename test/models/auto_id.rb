require 'rubygems'
require 'active_record'

class CreateAutoIds < ActiveRecord::Migration
  def self.up
    create_table "auto_ids", :force => true do |t|
      t.column :value, :integer
    end
  end

  def self.down
    drop_table "auto_ids"
  end
end

class AutoId < ActiveRecord::Base
  def self.table_name () "auto_ids" end
end

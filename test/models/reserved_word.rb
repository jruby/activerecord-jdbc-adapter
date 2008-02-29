require 'rubygems'
require 'active_record'

class CreateReservedWords < ActiveRecord::Migration
  def self.up
    create_table "reserved_words", :force => true do |t|
      t.column :position, :integer
      t.column :select, :integer
    end
  end

  def self.down
    drop_table "reserved_words"
  end
end

class ReservedWord < ActiveRecord::Base
end
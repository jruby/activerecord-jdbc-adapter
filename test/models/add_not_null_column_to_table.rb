require 'rubygems'
require 'active_record'

class AddNotNullColumnToTable < ActiveRecord::Migration
  def self.up
    add_column :entries, :color, :string, :null => false, :default => "blue"
  end

  def self.down
    remove_column :entries, :color
  end
end

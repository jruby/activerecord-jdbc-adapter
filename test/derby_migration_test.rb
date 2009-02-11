require 'jdbc_common'
require 'db/derby'

class CreateDummies < ActiveRecord::Migration
  def self.up
    create_table :dummies, :force => true do |t|
      t.string :year, :default => "", :null => false
    end
    add_index :dummies, :year, :unique => true
  end
  
end

class DerbyQuotingTest < Test::Unit::TestCase
  include FixtureSetup

  def test_create_table_column_quoting_vs_keywords
    CreateDummies.up
  end
  
end

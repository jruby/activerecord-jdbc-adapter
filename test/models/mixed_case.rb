require 'rubygems'
require 'active_record'

module Migration
  class MixedCase < ActiveRecord::Migration

    def self.up
      create_table "mixed_cases" do |t|
        t.column :SOME_value, :string
      end
      create_table "tblUsers" do |t|
        t.column :firstName, :string
        t.column :lastName, :string
      end
    end

    def self.down
      drop_table "mixed_cases"
      drop_table "tblUsers"
    end
  end
end

class MixedCase < ActiveRecord::Base
end

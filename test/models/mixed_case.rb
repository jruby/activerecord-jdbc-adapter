require 'rubygems'
require 'active_record'

module Migration
  class MixedCase < ActiveRecord::Migration
    
    def self.up
      create_table "mixed_cases" do |t|
        t.column :SOME_value, :string
      end
    end
    
    def self.down
      drop_table "mixed_cases"
    end
  end
end

class MixedCase < ActiveRecord::Base
end

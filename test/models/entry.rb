if RUBY_PLATFORM =~ /java/
  RAILS_CONNECTION_ADAPTERS = ['abstract', 'jdbc']
end

require 'rubygems'
require 'active_record'

class CreateEntries < ActiveRecord::Migration
  def self.up
    create_table "entries", :force => true do |t|
      t.column :title, :string, :limit => 100
      t.column :updated_on, :datetime
      t.column :content, :text
    end
    add_index(:entries, :title)
  end

  def self.down
    remove_index(:entries, :title)
    drop_table "entries"
  end
end

class Entry < ActiveRecord::Base
end

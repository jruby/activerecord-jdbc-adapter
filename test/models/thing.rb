class CreateThings < ActiveRecord::Migration
  def self.up
    create_table :things, :id => false do |t|
      t.string :name
      t.timestamps
    end
    add_index :things, :name, :unique => true
    add_index :things, :created_at, :where => 'name IS NOT NULL', :name => "thing_partial_index"
  end

  def self.down
    drop_table :things
  end
end

class Thing < ActiveRecord::Base
end

class CreateThings < ActiveRecord::Migration
  def self.up
    create_table :things, :id => false do |t|
      t.string :name

      t.timestamps
    end
  end

  def self.down
    drop_table :things
  end
end

class Thing < ActiveRecord::Base
end

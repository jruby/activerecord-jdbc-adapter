class AddNotNullColumnToTable < ActiveRecord::Migration[4.2]
  def self.up
    add_column :entries, :color, :string, :null => false, :default => "blue"
  end

  def self.down
    remove_column :entries, :color
  end
end

class Binary < ActiveRecord::Base
end

class BinaryMigration < ActiveRecord::Migration[4.2]

  def self.up
    create_table :binaries, :force => true do |t|
      t.string :name
      t.binary :data, :null => false
      t.binary :short_data, :limit => 2048, :null => true
    end
  end

  def self.down
    drop_table :binaries
  end

end

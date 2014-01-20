class UserMigration < ActiveRecord::Migration
  def self.up
    create_table "users", :force => true do |t|
      t.column :login, :string, :limit => 100, :null => false
      t.timestamps # created_at / updated_at
    end
  end

  def self.down
    drop_table "users"
  end
end
CreateUsers = UserMigration

class User < ActiveRecord::Base
  has_many :entries
end
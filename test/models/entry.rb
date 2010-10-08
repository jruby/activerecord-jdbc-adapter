require 'rubygems'
require 'active_record'

class CreateEntries < ActiveRecord::Migration
  def self.up
    create_table "entries", :force => true do |t|
      t.column :title, :string, :limit => 100
      t.column :updated_on, :datetime
      t.column :content, :text
      t.column :rating, :decimal, :precision => 10, :scale => 2
      t.column :user_id, :integer
    end
  end

  def self.down
    drop_table "entries"
  end
end

class Entry < ActiveRecord::Base
  belongs_to :user

  def to_param
    "#{id}-#{title.gsub(/[^a-zA-Z0-9]/, '-')}"
  end
end

class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table "users", :force => true do |t|
      t.column :login, :string, :limit => 100
    end
  end

  def self.down
    drop_table "users"
  end
end

class User < ActiveRecord::Base
  has_many :entries
end


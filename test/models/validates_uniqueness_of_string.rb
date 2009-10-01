class CreateValidatesUniquenessOfStrings < ActiveRecord::Migration
  def self.up
    create_table "validates_uniqueness_of_strings", :force => true do |t|
      t.column :case_sensitive_string, :string
      t.column :case_insensitive_string, :string
      t.column :content, :text
    end
  end

  def self.down
    drop_table "validates_uniqueness_of_strings"
  end
end

class ValidatesUniquenessOfString < ActiveRecord::Base
  validates_uniqueness_of :case_sensitive_string, :case_sensitive => true
  validates_uniqueness_of :case_insensitive_string, :case_sensitive => false
end

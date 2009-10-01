class CreateValidatesUniquenessOf < ActiveRecord::Migration
  def self.up
    create_table "validates_uniqueness_of", :force => true do |t|
      t.column :cs_string, :string
      t.column :ci_string, :string
      t.column :content, :text
    end
  end

  def self.down
    drop_table "validates_uniqueness_of"
  end
end

class ValidatesUniquenessOfString < ActiveRecord::Base
  self.set_table_name "validates_uniqueness_of"
  validates_uniqueness_of :cs_string, :case_sensitive => true
  validates_uniqueness_of :ci_string, :case_sensitive => false
end

class CreateCustomPkName < ActiveRecord::Migration
  def self.up
    create_table :custom_pk_names, :force => true, :id => false do |t|
      t.primary_key :custom_id
      t.string :name
    end
  end
  def self.down
    drop_table :custom_pk_names
  end
end
class CustomPkName < ActiveRecord::Base
  self.primary_key = "custom_id"
end

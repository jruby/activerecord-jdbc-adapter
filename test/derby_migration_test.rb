require 'jdbc_common'
require 'db/derby'

class CreateDummies < ActiveRecord::Migration
  def self.up
    create_table :dummies, :force => true do |t|
      t.string :year, :default => "", :null => false
    end
    add_index :dummies, :year, :unique => true
  end

end

class ChangeColumn < ActiveRecord::Migration
  def self.up
    create_table :people, :id => false, :force => true do |t|
      t.string :id, :limit => 22, :null => false
      t.string :name, :null => false
    end
    change_column(:people, :name, :string, {:limit=>22})
    execute("SELECT id FROM people WHERE id = 'some string'")
  end

  def self.down
  end

end

class CreateIndex < ActiveRecord::Migration
  def self.up
    create_table :people, :id => false, :force => true do |t|
      t.string :id, :limit => 22, :null => false
      t.string :first_name, :null => false
      t.string :last_name, :null => false
      t.string :nickname, :null => false
      t.string :long_name, :null => false
      t.string :very_long_name, :null => false
      t.string :extremely_long_name, :null => false
    end

    add_index(:people, [:first_name, :last_name, :nickname, :long_name, :very_long_name, :extremely_long_name], :unique => true)

    remove_index(:people, [:first_name, :last_name, :nickname, :long_name, :very_long_name, :extremely_long_name])
  end

  def self.down
  end

end

class DerbyMigrationTest < Test::Unit::TestCase
  include FixtureSetup

  def test_create_table_column_quoting_vs_keywords
    CreateDummies.up
  end

  def test_migrate_change_column_for_non_standard_id
    ChangeColumn.up
    ChangeColumn.down
  end

  def test_migrate_create_index
    CreateIndex.up
    CreateIndex.down
  end

end

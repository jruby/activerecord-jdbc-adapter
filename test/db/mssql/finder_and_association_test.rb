require 'test_helper'
require 'db/mssql'

class MSSQLFinderAndAssociationTest < Test::Unit::TestCase
  class CreateSimpleSchema < ActiveRecord::Migration
    def self.up
      create_table :writers do |t|
        t.string :email
        t.string :first_name
        t.string :last_name
        t.boolean :active
        t.time :publish_at
        t.date :birthday
        t.binary :photo
        t.text :notes

        t.timestamps
      end
      add_index :writers, :email, unique: true
      add_index :writers, :last_name

      create_table :categories do |t|
        t.string :name, null: false, limit: 200
        t.text :notes

        t.timestamps
      end

      create_table :stories do |t|
        t.references :writer, foreign_key: true
        t.references :category, foreign_key: true
        t.string :title, limit: 200, null: false
        t.boolean :online
        t.integer :likes
        t.integer :dislikes
        t.text :content

        t.timestamps
      end

      create_table :reviews do |t|
        t.references :stories, foreign_key: true
        t.integer :rate, limit: 2
        t.string :reviewer, limit: 150
        t.text :content

        t.timestamps
      end
    end

    def self.down
      drop_table :reviews
      drop_table :stories
      drop_table :categories
      drop_table :writers
    end
  end

  class Writer < ActiveRecord::Base
    has_many :stories
    has_many :categories, through: :stories
  end

  class Category < ActiveRecord::Base
    has_many :stories
  end

  class Story < ActiveRecord::Base
    belongs_to :writer
    belongs_to :category
    has_many :reviews
  end

  class Review < ActiveRecord::Base
    belongs_to :story
  end

  def self.startup
    CreateSimpleSchema.up
  end

  def self.shutdown
    CreateSimpleSchema.down
    ActiveRecord::Base.clear_active_connections!
  end

  def test_select_with_order_in_different_table
    # Under the hood this uses distinct in the select.
    dataset = Writer.includes(:categories).order('categories.name').limit(2)

    assert_equal [], dataset
  end

  def test_exists_with_distinct
    assert_equal false, Writer.distinct.order(:email).exists?
    assert_equal false, Writer.distinct.order(:email).limit(1).exists?
    assert_equal false, Writer.distinct.order(:email).limit(2).exists?
  end

end

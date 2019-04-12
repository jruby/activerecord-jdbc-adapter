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
        t.datetime :written_on
        t.text :content

        t.timestamps null: true
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
    author1 = Writer.create(email: 'jesse@melbourne')
    category1 = Category.create(name: 'scifi')
    author2 = Writer.create(email: 'jesse@sydney')
    category2 = Category.create(name: 'drama')

  end

  def self.shutdown
    CreateSimpleSchema.down
    ActiveRecord::Base.clear_active_connections!
  end

  def test_select_with_order_in_different_table
    dataset = Writer.distinct.includes(:categories).order('categories.name').limit(2)

    assert_equal Writer.all.count, dataset.size
  end

  def test_exists_with_distinct
    assert_equal true, Writer.distinct.order(:email).exists?
    assert_equal true, Writer.distinct.order(:email).limit(1).exists?
    assert_equal true, Writer.distinct.order(:email).limit(2).exists?
  end

  def test_find_by_datetime_field_hash_in_where
    author = Writer.find_by(email: 'jesse@melbourne')
    category = Category.find_by(name: 'scifi')

    sql_insert = %(
      INSERT INTO [stories]([title], [writer_id], [category_id], [written_on])
      VALUES('Star Wars 10',#{author.id}, #{category.id}, '2019-04-12T11:28:11.223')
    )

    Story.connection.execute(sql_insert)
    written_on = Time.parse('2019-04-12T11:28:11.223 +0000')

    assert_equal 1, Story.where(written_on: written_on).count
  end

  def test_find_by_datetime_field_array_in_where
    author = Writer.find_by(email: 'jesse@melbourne')
    category = Category.find_by(name: 'drama')

    sql_insert = %(
      INSERT INTO [stories]([title], [writer_id], [category_id], [written_on])
      VALUES('Star Wars 11',#{author.id}, #{category.id}, '2018-04-12T11:28:11.223')
    )

    Story.connection.execute(sql_insert)
    written_on = Time.parse('2018-04-12T11:28:11.223 +0000')

    assert_equal 1, Story.where(['written_on = ?', written_on]).count
  end
end

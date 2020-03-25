require 'test_helper'
require 'db/postgres'

class DateTest < Test::Unit::TestCase

  class CreatePosts < ActiveRecord::Migration[5.0]
    def self.up
      create_table :posts, force: true do |t|
        t.date :published_on
      end
    end
    def self.down
      drop_table :posts
    end
  end

  def setup
    CreatePosts.up
  end

  def teardown
    CreatePosts.down
  end

  class Post < ActiveRecord::Base
  end

  def test_prepared_statement_for_date_column_sends_correct_date_to_postgres
    Post.create!
    date = Date.new(2020, 2, 12)
    Post.first.update_columns published_on: date

    assert_equal date, Post.first.published_on
  ensure
    Post.connection.execute 'TRUNCATE posts;'
  end

  def test_unprepared_statement_for_date_column_sends_correct_date_to_postgres
    Post.create!
    date = Date.new(2020, 2, 12)

    ActiveRecord::Base.connection.unprepared_statement do
      Post.first.update_columns published_on: date
    end

    assert_equal date, Post.first.published_on
  ensure
    Post.connection.execute 'TRUNCATE posts;'
  end

  def test_raw_arel_for_date_column_sends_correct_date_to_postgres
    Post.create!
    date = Date.new(2020, 2, 12)

    update_arel = Arel::UpdateManager.new
    update_arel.table Post.arel_table
    update_arel.set [
                        [Post.arel_table[:published_on], date]
                    ]
    Post.connection.update update_arel

    assert_equal date, Post.first.published_on
  ensure
    Post.connection.execute 'TRUNCATE posts;'
  end
end

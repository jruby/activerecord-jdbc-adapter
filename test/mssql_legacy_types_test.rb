require 'jdbc_common'
require 'db/mssql'

ActiveRecord::Schema.verbose = false

class CreateArticles < ActiveRecord::Migration

  def self.up
    execute <<-SQL
      CREATE TABLE articles (
        [id] int NOT NULL IDENTITY(1, 1) PRIMARY KEY, 
        [title] VARCHAR(100), 
        [author] VARCHAR(60) DEFAULT 'anonymous', 
        [body] TEXT
      )
    SQL
  end

  def self.down
    drop_table "articles"
  end

end

class Article < ActiveRecord::Base
end

class MsSQLLegacyTypesTest < Test::Unit::TestCase

  def setup
    CreateArticles.up
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    CreateArticles.down
    ActiveRecord::Base.clear_active_connections!
  end

  def test_varchar_column
    Article.create!(:title => "Blah blah")
    article = Article.first
    assert_equal("Blah blah", article.title)
  end
  
  SAMPLE_TEXT = "Lorem ipsum dolor sit amet ..."
  
  def test_text_column
    Article.create!(:body => SAMPLE_TEXT)
    article = Article.first
    assert_equal(SAMPLE_TEXT, article.body)
  end
  
  def test_varchar_default_value
    assert_equal("anonymous", Article.new.author)
  end
  
end

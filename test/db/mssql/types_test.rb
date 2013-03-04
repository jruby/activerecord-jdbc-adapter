require 'test_helper'
require 'db/mssql'

class MSSQLDateTimeTypesTest < Test::Unit::TestCase
  
  TABLE_DEFINITION = <<-SQL
    CREATE TABLE date_and_times (
      [id] int NOT NULL IDENTITY(1, 1) PRIMARY KEY, 
      [datetime] DATETIME
    )
  SQL
  
  def self.startup
    ActiveRecord::Base.connection.execute TABLE_DEFINITION
    # ActiveRecord::Base.logger.level = Logger::DEBUG
  end

  def self.shutdown
    # ActiveRecord::Base.logger.level = Logger::WARN
    ActiveRecord::Base.connection.execute "DROP TABLE date_and_times"
  end
  
  class DateAndTime < ActiveRecord::Base; end
  
  def test_datetime
    # January 1, 1753, through December 31, 9999 + 00:00:00 through 23:59:59.997
    datetime = DateTime.parse('2012-12-21T21:11:01')
    model = DateAndTime.create! :datetime => datetime
    assert_datetime_equal datetime, model.reload.datetime
  end
  
  if ActiveRecord::Base.connection.sqlserver_version >= '2008'
    
    # 2008 Date and Time: http://msdn.microsoft.com/en-us/library/ff848733.aspx
    
    TABLE_DEFINITION.replace <<-SQL
      CREATE TABLE date_and_times (
        [id] int NOT NULL IDENTITY(1, 1), 
        [datetime] DATETIME,
        [date] DATE,
        [datetime2] DATETIME2, 
        [datetime25] DATETIME2(5), 
        [smalldatetime] SMALLDATETIME, 
        [time] TIME
        PRIMARY KEY CLUSTERED ( [id] ASC ) WITH ( 
          PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, 
          ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON
        ) ON [PRIMARY]
      )
    SQL
    
    def test_date
      # 0001-01-01 through 9999-12-31
      date = DateTime.parse('2012-12-31')
      model = DateAndTime.create! :date => date
      assert_instance_of Date, model.reload.date
      assert_date_equal date.to_date, model.date
    end
    
    def test_datetime2
      # date range + 00:00:00 through 23:59:59.9999999
      datetime = DateTime.parse('2012-12-21T21:11:01')
      model = DateAndTime.create! :datetime2 => datetime
      assert_not_nil model.datetime2
      assert_datetime_equal datetime, model.reload.datetime2
      
#      datetime = Time.local(1982, 7, 13, 02, 24, 56, 12345)
#      model = DateAndTime.create! :datetime25 => datetime
#      assert_not_nil model.datetime25
#      assert_equal datetime, model.reload.datetime25
    end

    def test_smalldatetime
      # 1900-01-01 through 2079-06-06 + 00:00:00 through 23:59:59
      # with seconds always zero - rounded to the nearest minute
      datetime = DateTime.parse('1999-12-31T23:59:21')
      model = DateAndTime.create! :smalldatetime => datetime
      datetime = DateTime.parse('1999-12-31T23:59:00')
      assert_datetime_equal datetime, model.reload.smalldatetime
      
      datetime = DateTime.parse('1999-12-31T22:59:31')
      model = DateAndTime.create! :smalldatetime => datetime
      datetime = DateTime.parse('1999-12-31T23:00:00')
      assert_datetime_equal datetime, model.reload.smalldatetime
    end
    
#    def test_time
#      # 00:00:00.0000000 through 23:59:59.9999999
#      time = Time.local(0000, 1, 01, 23, 59, 58, 0)
#      model = DateAndTime.create! :time => time
#      assert_not_nil model.time
#      assert_time_equal time, model.reload.time
#    end
    
  end
  
end

class MSSQLLegacyTypesTest < Test::Unit::TestCase

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

  class Article < ActiveRecord::Base; end
  
  def self.startup; CreateArticles.up; end

  def self.shutdown; CreateArticles.down; end

  def teardown
    ActiveRecord::Base.clear_active_connections!
  end
  
  def test_varchar_column
    
    ActiveRecord::Base.logger.level = Logger::DEBUG
    
    Article.create! :title => "Blah blah"
    article = Article.first
    assert_equal("Blah blah", article.title)
  ensure
    
    ActiveRecord::Base.logger.level = Logger::WARN
    
  end
  
  def test_text_column
    sample_text = "Lorem ipsum dolor sit amet ..."
    Article.create! :body => sample_text.dup
    article = Article.first
    assert_equal(sample_text, article.body)
  end
  
  def test_varchar_default_value
    assert_equal("anonymous", Article.new.author)
  end
  
end

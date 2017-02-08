require 'test_helper'
require 'arjdbc/mssql'

class MSSQLDatetime2 < Test::Unit::TestCase
  
  test "datetime2 support" do
    if ActiveRecord::Base.connection.sqlserver_version.to_i >= 2008
      create_table_sql = <<-sql
        USE [weblog_development]
        IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[date_time_checks]') AND type in (N'U'))
        DROP TABLE [dbo].[date_time_checks]

        CREATE TABLE [dbo].[date_time_checks](
          [id] [int] IDENTITY(1,1) NOT NULL,
          [checked_at] [datetime2](7) NOT NULL,
          [created_at] [datetime2](7) NOT NULL,
          [updated_at] [datetime2](7) NOT NULL,
          PRIMARY KEY CLUSTERED 
          (
            [id] ASC
            )WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
        ) ON [PRIMARY]
      sql

      class DateTimeCheck < ActiveRecord::Base
      end

      connection = ActiveRecord::Base.connection.raw_connection
      connection.execute create_table_sql

      date_time = DateTimeCheck.new
      date_time.checked_at = Time.now
      assert date_time.save!

      date_time = DateTimeCheck.first
      assert date_time.checked_at
    end
  end
end

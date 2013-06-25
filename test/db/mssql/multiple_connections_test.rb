require 'test_helper'
require 'db/mssql'

class MSSQLMultipleConnectionsTest < Test::Unit::TestCase

  MSSQL_CONFIG2 = { :adapter  => 'mssql' }
  MSSQL_CONFIG2[:database] = ENV['SQL2DATABASE']
  MSSQL_CONFIG2[:username] = ENV['SQL2USER'] || MSSQL_CONFIG[:username]
  MSSQL_CONFIG2[:password] = ENV['SQL2PASS'] || MSSQL_CONFIG[:password]
  MSSQL_CONFIG2[:host] = MSSQL_CONFIG[:host]
  MSSQL_CONFIG2[:port] = MSSQL_CONFIG[:port]

  OLD_CONFIG = ActiveRecord::Base.configurations.dup

  if MSSQL_CONFIG2[:database]

    class Database1 < ActiveRecord::Base
      self.abstract_class = true
      #establish_connection 'db1'
    end

    class Model1 < Database1
    end

    class Database2 < ActiveRecord::Base
      self.abstract_class = true
      #establish_connection 'db2'
    end

    class Model2 < Database2
    end

    def self.startup
      super
      ActiveRecord::Base.clear_active_connections!
      ActiveRecord::Base.configurations.replace('db1' => MSSQL_CONFIG, 'db2' => MSSQL_CONFIG2)

      Database1.establish_connection 'db1'
      Database2.establish_connection 'db2'

      Database1.connection.execute "CREATE TABLE [model1s] " +
        "([id] int NOT NULL IDENTITY(1, 1) PRIMARY KEY, [name] NVARCHAR(10))"
      Database2.connection.execute "CREATE TABLE [model2s] " +
        "([id] int NOT NULL IDENTITY(1, 1) PRIMARY KEY, [name] NVARCHAR(10))"
    end

    def self.shutdown
      Database1.connection.execute "DROP TABLE [model1s]"
      Database2.connection.execute "DROP TABLE [model2s]"

      ActiveRecord::Base.clear_active_connections!

      ActiveRecord::Base.configurations.replace OLD_CONFIG
      ActiveRecord::Base.establish_connection MSSQL_CONFIG
      super
    end

    test "create and retrieve models" do
      assert_nil Model1.first
      assert_nil Model2.first

      Model1.create :name => 'm1'
      Model2.create :name => 'm2'

      assert_not_nil Model1.first
      assert_not_nil Model2.first
    end

  else
    puts "#{self.name} skipped since no second MS-SQL database configured"
  end

end
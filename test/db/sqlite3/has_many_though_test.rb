require 'db/sqlite3'
require 'has_many_through'

class SQLite3HasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods

  def self.startup
    puts "Using SQLite: #{ActiveRecord::Base.connection.send(:sqlite_version)}"
  end

end
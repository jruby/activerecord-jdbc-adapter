require 'test_helper'
require 'db/mssql'

module MSSQLMigration
 class ForeignKeysTest < Test::Unit::TestCase
   class Pet < ActiveRecord::Base
   end

   def test_create_table_with_query
     Pet.connection.create_table(:pets, force: true)

     Pet.connection.create_table :table_from_query_testings, as: 'SELECT id FROM pets'

     columns = Pet.connection.columns(:table_from_query_testings)
     assert_equal 1, columns.length
     assert_equal 'id', columns.first.name
   ensure
     Pet.connection.drop_table :table_from_query_testings rescue nil
   end

   def test_create_table_with_query_from_relation
     Pet.connection.create_table(:pets, force: true)

     Pet.connection.create_table :table_from_query_testings, as: Pet.select(:id)

     columns = Pet.connection.columns(:table_from_query_testings)
     assert_equal 1, columns.length
     assert_equal 'id', columns.first.name
   ensure
     Pet.connection.drop_table :table_from_query_testings rescue nil
   end
 end
end

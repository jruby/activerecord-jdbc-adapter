require 'test_helper'
require 'db/mssql'
require 'db/mssql/migration/helper'

module MSSQLMigration
 class ForeignKeysTest < Test::Unit::TestCase
   include TestHelper

   def test_add_on_delete_cascade_foreign_key
     @connection.add_foreign_key :reviews, :entries, column: 'entry_id', on_delete: :cascade

     foreign_keys = @connection.foreign_keys('reviews')
     assert_equal 1, foreign_keys.size

     fk = foreign_keys.first
     assert_equal :cascade, fk.on_delete
   end

   def test_add_on_delete_nullify_foreign_key
     @connection.add_foreign_key :reviews, :entries, column: 'entry_id', on_delete: :nullify

     foreign_keys = @connection.foreign_keys('reviews')
     assert_equal 1, foreign_keys.size

     fk = foreign_keys.first
     assert_equal :nullify, fk.on_delete
   end

   def test_on_update_and_on_delete_raises_with_invalid_values
     assert_raises ArgumentError do
       @connection.add_foreign_key :reviews, :entries, column: 'entry_id', on_delete: :invalid
     end

     assert_raises ArgumentError do
       @connection.add_foreign_key :reviews, :entries, column: 'entry_id', on_update: :invalid
     end
   end

   def test_add_foreign_key_with_on_update
     @connection.add_foreign_key :reviews, :entries, column: 'entry_id', on_update: :nullify

     foreign_keys = @connection.foreign_keys('reviews')
     assert_equal 1, foreign_keys.size

     fk = foreign_keys.first
     assert_equal :nullify, fk.on_update
   end

 end
end

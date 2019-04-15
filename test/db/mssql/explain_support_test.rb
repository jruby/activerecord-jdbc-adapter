require 'db/mssql'
require 'models/entry'
require 'explain_support_test_methods'

class MSSQLExplainTest < Test::Unit::TestCase
 include ExplainSupportTestMethods

 def setup
   CreateUsers.up
   CreateEntries.up
 end

 def teardown
   CreateEntries.down
   CreateUsers.down
   ActiveRecord::Base.clear_active_connections!
 end

 def test_relation_explain
   create_explain_data
   explanation = Entry.where(content: 'content').explain

   assert_match(/^EXPLAIN for:/, explanation)
 end

 def test_explain_without_binds
   super
 end

 def test_explain_with_binds
   super
 end
end

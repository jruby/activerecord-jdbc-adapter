require 'test_helper'
require 'db/postgres'

# NOTE: named to execute before: 
# - PostgresConnectionTest
# - PostgresDbCreateTest
# - PostgresDbDropTest
# since on 3.1 otherwise starts weirdly failing (when full suite is run) :
# 
#   ActiveRecord::JDBCError: org.postgresql.util.PSQLException: ERROR: 
#   null value in column "uhash" violates not-null constraint
#     Detail: Failing row contains (null, http://url.to).: 
#     INSERT INTO "some_urls" ("url") VALUES ('http://url.to') RETURNING "uhash"
#
class PostgresACustomPrimaryKeyTest < Test::Unit::TestCase
  
  class CreateUrls < ActiveRecord::Migration
    def self.up
      create_table 'some_urls', :id => false do |t|
        t.string :uhash, :null => false
        t.text :url, :null => false
      end
      execute "ALTER TABLE some_urls ADD PRIMARY KEY (uhash)"
    end
    def self.down
      drop_table 'some_urls'
    end
  end
  
  def setup
    CreateUrls.up
  end

  def teardown
    CreateUrls.down
  end

  class SomeUrl < ActiveRecord::Base
    self.primary_key = :uhash
  end
  
  def test_create_url
    url = SomeUrl.create! do |instance|
      instance.uhash = 'uhash'
      instance.url = 'http://url.to'
    end
    assert_equal 'uhash', url.reload.uhash
  end
  
end

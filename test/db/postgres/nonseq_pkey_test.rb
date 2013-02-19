require 'jdbc_common'
require 'db/postgres'

class PostgresNonSeqPKeyTest < Test::Unit::TestCase
  
  class CreateUrls < ActiveRecord::Migration
    def self.up
      create_table 'urls', :id => false do |t|
        t.text :uhash, :null => false
        t.text :url,  :null => false
      end
      execute "ALTER TABLE urls ADD PRIMARY KEY (uhash)"
    end
    def self.down
      drop_table 'urls'
    end
  end

  class Url < ActiveRecord::Base
    self.primary_key = :uhash
    # shouldn't be needed: set_sequence_name nil
  end
  
  def setup
    CreateUrls.up
  end

  def teardown
    CreateUrls.down
  end

  def test_create
    url = Url.create! do |u|
      u.uhash = 'uhash'
      u.url = 'http://url'
    end
    assert_equal( 'uhash', url.uhash )
  end
end

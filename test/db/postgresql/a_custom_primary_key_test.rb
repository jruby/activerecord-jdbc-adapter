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
    self.primary_key = 'uhash' # :uhash won't work correctly on 3.1
  end

  def test_create_url
    url = SomeUrl.new
    url.uhash = 'uhash1'
    url.url = 'http://url.to'
    url.save!
    assert_equal 'uhash1', url.reload.uhash

    url = SomeUrl.create! do |instance|
      instance.uhash = 'uhash2'
      instance.url = 'http://url.to'
    end
    assert_equal 'uhash2', url.reload.uhash
  end

end


class PostgresInsertTriggerPrimaryKeyTest < Test::Unit::TestCase

  def setup
    connection.execute "CREATE TABLE some_foos ( id integer NOT NULL, balance numeric, CONSTRAINT some_foos_pkey PRIMARY KEY (id) )"
    connection.execute("CREATE OR REPLACE FUNCTION generate_foo_id() RETURNS TRIGGER AS $$
begin
    if new.id is NULL then
        new.id := floor( random() * 1000 + 1 );
    end if;
    return new;
end
$$ language plpgsql;")
    connection.execute "CREATE TRIGGER foo_id_trigger BEFORE INSERT ON some_foos FOR EACH ROW EXECUTE PROCEDURE generate_foo_id();"
  end

  def teardown
    connection.execute "DROP TRIGGER IF EXISTS foo_id_trigger ON some_foos"
    connection.drop_table :some_foos
  end

  class SomeFoo < ActiveRecord::Base
    # self.primary_key = 'id'
  end

  def test_create_foo
    foo = SomeFoo.create!(:balance => 42)
    puts "connection.use_insert_returning? #{connection.use_insert_returning?}"
    assert_not_nil foo.id if connection.use_insert_returning?
    assert_not_nil ( foo = SomeFoo.first ).id
    assert_equal 42.0, foo.balance
  end

end
require 'db/postgres'
require 'change_column_test_methods'

class PostgreSQLColumnTest < Test::Unit::TestCase
  include ChangeColumnTestMethods
end

class PostgreSQLColumnDefaultTest < Test::Unit::TestCase

  class Project < ActiveRecord::Base; end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.transaction do
      @connection.create_table 'projects', force: :cascade do |t|
        t.string "name", limit: 255, default: ' '
        t.text   "some_ids", array: true, default: []
      end
    end
  end

  def teardown
    @connection.execute 'DROP TABLE IF EXISTS projects'
  end

  test 'default value from column is not shared' do
    assert_equal ' ', Project.columns_hash['name'].default

    p = Project.create!
    assert_equal ' ', p.name
    p.name.replace '1-replaced'

    p = Project.new; p.name << '2-append'; p.save!
    assert_equal ' ', Project.columns_hash['name'].default

    p = Project.new; p.name << '3-append'
    assert_equal ' ', Project.columns_hash['name'].default
  end

  test '_ids assingment incorrect array column default (shared bug)' do
    Project.create!(:name => 'p1', :some_ids => ['1'])
    p = Project.new(:name => 'p2'); p.some_ids << '2'; p.save!

    if ar_version('4.2')
      assert_equal '{}', Project.columns_hash['some_ids'].default
    else
      assert_equal [], Project.columns_hash['some_ids'].default
    end

    assert_equal ['2'], p.some_ids
    if ar_version('4.2')
      assert_equal ['2'], p.reload.some_ids
    else
      # MRI under AR 4.1 gets messed up the same :
      assert_equal [], p.reload.some_ids
    end

    p = Project.new(:name => 'p3')
    assert_equal [], p.some_ids
    p.save!
    assert_equal [], p.some_ids
  end

end if Test::Unit::TestCase.ar_version('4.0')
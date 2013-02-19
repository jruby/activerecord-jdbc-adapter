require 'jdbc_common'
require 'db/mysql'

class Project < ActiveRecord::Migration
  def self.up
    create_table :project, :primary_key => "project_id" do |t|
      t.string      :projectType, :limit => 31
      t.boolean     :published
      t.datetime    :created_date
      t.text        :abstract, :title
    end
  end

  def self.down
    drop_table :project
  end

end

class MysqlNonstandardPrimaryKeyTest < Test::Unit::TestCase

  def setup
    Project.up
  end

  def teardown
    Project.down
  end

  def standard_dump
    stream = StringIO.new
    ActiveRecord::SchemaDumper.ignore_tables = []
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    stream.string
  end

  def test_nonstandard_primary_key
    output = standard_dump
    assert_match %r(:primary_key => "project_id"), output, "non-standard primary key not preserved"
  end

end

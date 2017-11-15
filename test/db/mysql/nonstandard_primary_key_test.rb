require 'jdbc_common'
require 'db/mysql'

class MysqlNonstandardPrimaryKeyTest < Test::Unit::TestCase

  class Project < ActiveRecord::Migration[4.2]
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
  
  def setup
    Project.up
  end

  def teardown
    Project.down
  end

  def test_nonstandard_primary_key
    output = schema_dump
    if ar_version('4.0')
      assert_match %r(primary_key: "project_id"), output, "non-standard primary key not preserved"
    else
      assert_match %r(:primary_key => "project_id"), output, "non-standard primary key not preserved"
    end
  end

end

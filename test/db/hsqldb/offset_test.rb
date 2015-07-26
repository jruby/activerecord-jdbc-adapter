require 'test_helper'
require 'db/hsqldb'

class H2OffsetTest < Test::Unit::TestCase

  class Persona < ActiveRecord::Base
  end

  class CreatePersonasTable < ActiveRecord::Migration
    def self.up
      create_table :personas do |t|
        t.string :firstname
        t.string :lastname
      end
    end

    def self.down
      drop_table :personas
    end
  end

  def setup
    CreatePersonasTable.up
    Persona.create(:firstname => "John",     :lastname => "Smith")
    Persona.create(:firstname => "Jill",     :lastname => "Smith")
    Persona.create(:firstname => "Joan",     :lastname => "Smith")
    Persona.create(:firstname => "Jason",    :lastname => "Smith")
    Persona.create(:firstname => "Jack",     :lastname => "Smith")
    Persona.create(:firstname => "Jenssen",  :lastname => "Smith")
    Persona.create(:firstname => "Joe",      :lastname => "Smith")
    Persona.create(:firstname => "Johanna",  :lastname => "Smith")
    Persona.create(:firstname => "James",    :lastname => "Smith")
    Persona.create(:firstname => "Jim",      :lastname => "Smith")
    Persona.create(:firstname => "Jody",     :lastname => "Smith")
  end

  def teardown
    CreatePersonasTable.down
  end

  def test_offset
    query = Persona.order(:lastname, :firstname)
    assert_equal ['Jack', 'James', 'Jason'], query.limit(3).map(&:firstname)
    assert_equal ['Joe', 'Johanna', 'John'], query.offset(8).map(&:firstname)
    assert_equal ['Joe', 'Johanna'], query.offset(8).limit(2).map(&:firstname)
  end if ar_version('3.0')

  def test_offset_arel
    query = Arel::Table.new(:persons).skip(3)
    assert_nothing_raised do
      sql = query.to_sql
      if ArJdbc::AR42
        assert_equal 'SELECT FROM persons LIMIT 0 OFFSET 3', sql, 'SQL statement was not generated, properly'
      else
        assert_equal "SELECT LIMIT 3", sql[0..13], "SQL statement was not generated, properly"
      end
    end
  end if ar_version('3.0')

end

require 'test_helper'
require 'db/h2'

class H2IdentityColumnTest < Test::Unit::TestCase

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
  end

  def teardown
    CreatePersonasTable.down
  end

  def test_auto_increment
    assert_equal 1, Persona.all[0].id, "H2 auto increment initially should start at ID 1, not 0"
  end
end


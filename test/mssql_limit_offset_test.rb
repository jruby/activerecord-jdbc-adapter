require 'jdbc_common'
require 'db/mssql'

ActiveRecord::Schema.verbose = false

class CreateLegacyShips < ActiveRecord::Migration

  def self.up
    create_table "legacy_ships",{:primary_key => :ShipKey} do |t|
      t.string "name", :limit => 50, :null => false
      t.integer "width", :default => 123
      t.integer "length", :default => 456
    end
  end

  def self.down
    drop_table "legacy_ships"
  end

end

class LegacyShip < ActiveRecord::Base
  self.primary_key = "ShipKey"
end

class CreateLongShips < ActiveRecord::Migration

  def self.up
    create_table "long_ships", :force => true do |t|
      t.string "name", :limit => 50, :null => false
      t.integer "width", :default => 123
      t.integer "length", :default => 456
    end
  end

  def self.down
    drop_table "long_ships"
  end

end

class LongShip < ActiveRecord::Base
  has_many :vikings
end

class CreateVikings < ActiveRecord::Migration

  def self.up
    create_table "vikings", :force => true do |t|
      t.integer "long_ship_id", :null => false
      t.string "name", :limit => 50, :default => "Sven"
    end
  end

  def self.down
    drop_table "vikings"
  end

end

class Viking < ActiveRecord::Base
  belongs_to :long_ship
end


class CreateNoIdVikings < ActiveRecord::Migration
  def self.up
    create_table "no_id_vikings", :force => true do |t|
      t.string "name", :limit => 50, :default => "Sven"
    end
    remove_column "no_id_vikings", "id"
  end

  def self.down
    drop_table "no_id_vikings"
  end
end

class NoIdViking < ActiveRecord::Base
end



class MsSQLLimitOffsetTest < Test::Unit::TestCase

  def setup
    CreateLegacyShips.up
    CreateLongShips.up
    CreateVikings.up
    CreateNoIdVikings.up
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    CreateLegacyShips.down
    CreateVikings.down
    CreateLongShips.down
    CreateNoIdVikings.down
    ActiveRecord::Base.clear_active_connections!
  end

  def test_limit_with_no_id_column_available
    NoIdViking.create!(:name => 'Erik')
    assert_nothing_raised(ActiveRecord::StatementInvalid) do 
      NoIdViking.find(:first)
    end
  end

  def test_limit_with_alternate_named_primary_key
    %w(one two three four five six seven eight).each do |name|
      LegacyShip.create!(:name => name)
    end
    ships = LegacyShip.limit(3)
    assert_equal(3, ships.size)
  end

  def test_limit_and_offset
    %w(one two three four five six seven eight).each do |name|
      LongShip.create!(:name => name)
    end
    ship_names = LongShip.find(:all, :offset => 2, :limit => 3).map(&:name)
    assert_equal(%w(three four five), ship_names)
  end

  def test_limit_and_offset_with_order
    %w(one two three four five six seven eight).each do |name|
      LongShip.create!(:name => name)
    end
    ship_names = LongShip.find(:all, :order => "name", :offset => 4, :limit => 2).map(&:name)
    assert_equal(%w(seven six), ship_names)
  end

  # TODO: work out how to fix DISTINCT support without breaking :include
  # def test_limit_and_offset_with_distinct
  #   %w(c a b a b a c d c d).each do |name|
  #     LongShip.create!(:name => name)
  #   end
  #   ship_names = LongShip.find(:all, :select => "DISTINCT name", :order => "name", :offset => 1, :limit => 2).map(&:name)
  #   assert_equal(%w(b c), ship_names)
  # end

  def test_limit_and_offset_with_include
    skei = LongShip.create!(:name => "Skei")
    skei.vikings.create!(:name => "Bob")
    skei.vikings.create!(:name => "Ben")
    skei.vikings.create!(:name => "Basil")
    ships = Viking.find(:all, :include => :long_ship, :offset => 1, :limit => 2)
    assert_equal(2, ships.size)
  end

  def test_limit_and_offset_with_include_and_order

    boat1 = LongShip.create!(:name => "1-Skei")
    boat2 = LongShip.create!(:name => "2-Skei")

    boat1.vikings.create!(:name => "Adam")
    boat2.vikings.create!(:name => "Ben")
    boat1.vikings.create!(:name => "Carl")
    boat2.vikings.create!(:name => "Donald")
  
    vikings = Viking.find(:all, :include => :long_ship, :order => "long_ships.name, vikings.name", :offset => 0, :limit => 3)
    assert_equal(["Adam", "Carl", "Ben"], vikings.map(&:name))

  end
  
end

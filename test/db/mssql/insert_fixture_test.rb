require 'test_helper'
require 'db/mssql'
require 'active_record/fixtures'

class MSSQLInsertFixturesTest < Test::Unit::TestCase
  class CreateFixtureEntries < ActiveRecord::Migration
    def self.up
      create_table :fixture_entries do |t|
        t.column :foreign_id, :integer
        t.column :code, :string, limit: 5
        t.column :title, :string
        t.column :notes, :text
        t.column :cookies, :boolean
        t.column :lucky_number, :integer
        t.column :starts, :float
        t.column :balance, :decimal
        t.column :total, :decimal, precision: 15, scale: 2
        t.column :binary_data, :binary
        t.column :birthday, :date
        t.column :expires_at, :datetime
        t.column :start_at, :time

        # treated as date "_on" convention
        t.column :created_on, :datetime
        t.column :updated_on, :datetime
      end

      create_table :modern_timestamps do |t|
        t.column :name, :string
        t.column :created_on, :datetime, null: false
        t.column :updated_on, :datetime, null: false
      end

      create_table :legacy_timestamps do |t|
        t.column :name, :string
        t.column :created_on, :datetime_basic, null: false
        t.column :updated_on, :datetime_basic, null: false
      end
    end

    def self.down
      drop_table :fixture_entries
      drop_table :modern_timestamps
      drop_table :legacy_timestamps
    end
  end

  class FixtureEntry < ActiveRecord::Base
  end

  def self.startup
    CreateFixtureEntries.up
  end

  def self.shutdown
    CreateFixtureEntries.down
    ActiveRecord::Base.clear_active_connections!
  end

  def test_insert_binary_assets
    assets_root = File.expand_path('../../assets', File.dirname(__FILE__))
    assets = %w(flowers.jpg example.log test.txt)

    assets.each.with_index(1) do |filename, index|
      data = File.read("#{assets_root}/#{filename}")
      data.force_encoding('ASCII-8BIT') if data.respond_to?(:force_encoding)
      data.freeze

      fixture = { id: index, binary_data: data }
      FixtureEntry.connection.insert_fixture(fixture, :fixture_entries)

      record = FixtureEntry.find(index)

      assert_equal data, record.binary_data, 'Newly assigned data differs from original'
    end


  end

  def test_insert_binary_other_types
    other_types = [12, 3.1415, true, false, Time.current, Date.today, 'qwerty']

    other_types.each.with_index(10) do |item, index|
      fixture = { id: index, binary_data: item }
      FixtureEntry.connection.insert_fixture(fixture, :fixture_entries)

      record = FixtureEntry.find(index)

      assert_equal item.to_s, record.binary_data, 'Newly assigned data differs from original'
    end
  end

  def test_insert_time
    fixture_one = { start_at: '11:00' }
    fixture_two = { start_at: Time.current }

    FixtureEntry.connection.insert_fixture(fixture_one, :fixture_entries)
    FixtureEntry.connection.insert_fixture(fixture_two, :fixture_entries)
  end

  def test_fixture_modern_timestamps
    fixtures_path = File.expand_path('fixtures', File.dirname(__FILE__))

    ActiveRecord::FixtureSet.create_fixtures(fixtures_path, 'modern_timestamps')
  end

  def test_fixture_legacy_timestamps
    fixtures_path = File.expand_path('fixtures', File.dirname(__FILE__))

    ActiveRecord::FixtureSet.create_fixtures(fixtures_path, 'legacy_timestamps')
  end
end

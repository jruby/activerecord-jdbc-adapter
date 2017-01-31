require 'test_helper'
require 'db/postgres'

class CompositePrimaryKeysTest < Test::Unit::TestCase
  if %w[3.1 3.2 4.0 4.1 4.2].any? { |version| ar_version(version) }
    class CreateMemberships < ActiveRecord::Migration
      def self.up
        create_table 'memberships', :id => false do |t|
          t.integer :record_id, :null => false
          t.integer :other_record_id, :null => false
        end
        execute 'ALTER TABLE "memberships" ADD PRIMARY KEY ("record_id", "other_record_id")'
      end

      def self.down
        drop_table 'memberships'
      end
    end

    require 'composite_primary_keys'

    class Membership < ActiveRecord::Base
      if Test::Unit::TestCase.ar_version('3.1')
        set_primary_keys :record_id, :other_record_id
      else
        self.primary_keys = :record_id, :other_record_id
      end
    end

    def setup
      CreateMemberships.up
    end

    def teardown
      CreateMemberships.down
    end

    def test_create_record_with_composite_primary_key
      membership = Membership.create!(:record_id => 123, :other_record_id => 456)
      assert_equal membership.id, [123, 456]
    end
  end
end


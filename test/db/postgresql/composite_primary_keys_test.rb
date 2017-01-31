require 'test_helper'
require 'db/postgres'

class CompositePrimaryKeysTest < Test::Unit::TestCase
  if ar_version('4.2')
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
      self.primary_keys = :record_id, :other_record_id
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


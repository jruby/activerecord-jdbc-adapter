# encoding: utf-8
require 'test_helper'
require 'models/binary'

# Kindly borrowed from Rails's AR test cases !

# Without using prepared statements, it makes no sense to test
# BLOB data with DB2 or Firebird, because the length of a statement
# is limited to 32KB.
#unless current_adapter?(:SybaseAdapter, :DB2Adapter, :FirebirdAdapter)

module BinaryTestMethods

  def self.included(base)
    base.extend UpAndDown
  end

  module UpAndDown

    def startup
      super
      BinaryMigration.up
    end

    def shutdown
      super
      BinaryMigration.down
    end

  end

  FIXTURES = %w(flowers.jpg example.log test.txt)

  def test_mixed_encoding_data
    data = "\x80"
    data.force_encoding('ASCII-8BIT') if data.respond_to?(:force_encoding)

    model = Binary.new :name => 'いただきます！', :data => data, :short_data => ''
    model.save!
    assert_equal data, model.reload.data

    name = model.name

    assert_equal 'いただきます！', name
  end

  def test_load_save_data
    Binary.delete_all
    assets_root = File.expand_path('assets', File.dirname(__FILE__))
    FIXTURES.each do |filename|
      data = File.read("#{assets_root}/#{filename}")
      data.force_encoding('ASCII-8BIT') if data.respond_to?(:force_encoding)
      data.freeze

      model = Binary.new(:data => data, :short_data => '')
      assert_equal data, model.data, 'Newly assigned data differs from original'

      model.save!
      assert_equal data, model.data, 'Data differs from original after save'

      assert_equal data, model.reload.data, 'Reloaded data differs from original'
    end
  end

  def test_insert_null_data
    model = Binary.create!(:data => 'some-data', :short_data => nil)
    assert_nil model.short_data
    assert_nil model.reload.short_data
  end

end

#end

require 'test_helper'
require 'models/topic'

class BindParamsLengthTest < Test::Unit::TestCase
  def setup
    TopicMigration.up
    Topic.create!(title: 'blub')
  end

  def teardown
    TopicMigration.down
  end

  def test_bind_param_length
    assert Topic.where(id: [1] * 35000).first
  end
end

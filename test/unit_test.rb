require 'test_helper'
require 'arjdbc/tasks/jdbc_database_tasks'

module ArJdbc
  class WarnTest < Test::Unit::TestCase

    test 'warn' do
      ArJdbc.warn "a warning from #{self}"
      assert ArJdbc.warn("another warning from #{self}", true)
      assert ! ArJdbc.warn("another warning from #{self}", true)
      assert ! ArJdbc.warn("another warning from #{self}", true)
    end

    test 'deprecate' do
      ArJdbc.deprecate "a deprecation from #{self}"
      assert ArJdbc.deprecate("another deprecation from #{self}", true)
      assert ! ArJdbc.deprecate("another deprecation from #{self}", true)
      assert ! ArJdbc.deprecate("another deprecation from #{self}", true)
    end

  end
end
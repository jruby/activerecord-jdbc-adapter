require 'test_helper'

module Jdbc
  class PostgresTest < Test::Unit::TestCase
    SYSTEM_ENV = ENV_JAVA.dup

    setup do
      require 'jdbc/postgres'
    end

    teardown do
      ENV_JAVA.clear; ENV_JAVA.update SYSTEM_ENV
    end

    test('some') { assert Jdbc::Postgres }

    test 'returns jdbc version default (4.2) on java 8' do
      ENV_JAVA['java.specification.version'] = '1.8'

      assert_nil Jdbc::Postgres.send(:jre_version)
    end

    test 'returns jdbc version 4.2 on java 11' do
      ENV_JAVA['java.specification.version'] = '11'

      assert_nil Jdbc::Postgres.send(:jre_version)
    end
  end
end

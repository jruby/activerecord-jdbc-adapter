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

    test 'returns jdbc version 3 on java 5 (only for compatibility)' do
      ENV_JAVA[ 'java.specification.version' ] = '1.5'
      assert_equal 5, Jdbc::Postgres.send(:jre_version)
    end unless SKIP_TESTS

    test 'returns jdbc version 4 on java 6' do
      ENV_JAVA[ 'java.specification.version' ] = '1.6'
      assert_equal 6, Jdbc::Postgres.send(:jre_version)
    end unless SKIP_TESTS

    test 'returns jdbc version 4.1 on java 7' do
      ENV_JAVA[ 'java.specification.version' ] = '1.7'
      assert_equal 7, Jdbc::Postgres.send(:jre_version)
    end unless SKIP_TESTS

    test 'returns jdbc version default (4.2) on java 8/9' do
      ENV_JAVA[ 'java.specification.version' ] = '1.8'
      assert_nil Jdbc::Postgres.send(:jre_version)

      ENV_JAVA[ 'java.specification.version' ] = '9'
      assert_nil Jdbc::Postgres.send(:jre_version)
    end unless SKIP_TESTS

    context 'load-driver' do

      ROOT_DIR = File.expand_path('../../..', File.dirname(__FILE__))

      @@driver_dir = File.join(ROOT_DIR, 'jdbc-postgres/lib')

      test 'on java 7' do
        ENV_JAVA[ 'java.specification.version' ] = '1.7'
        Jdbc::Postgres.expects(:load).with do |driver_jar|
          assert_match(/.jdbc41.jar$/, driver_jar)
          full_path = File.join(@@driver_dir, driver_jar)
          assert File.exist?(full_path), "#{driver_jar.inspect} not found in: #{@@driver_dir.inspect}"
          true
        end
        Jdbc::Postgres.load_driver
      end

    end

  end
end

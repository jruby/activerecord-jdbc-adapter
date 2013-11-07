require 'test_helper'
require 'jdbc/postgres'

module Jdbc
  class PostgresTest < Test::Unit::TestCase

    SYSTEM_ENV = ENV_JAVA.dup

    teardown do
      ENV_JAVA.replace SYSTEM_ENV
    end

    test 'returns jdbc version 3 on java 5 (only for compatibility)' do
      ENV_JAVA[ 'java.specification.version' ] = '1.5'
      assert_equal 3, Jdbc::Postgres.send(:jdbc_version)
    end

    test 'returns jdbc version 4 on java 6' do
      ENV_JAVA[ 'java.specification.version' ] = '1.6'
      assert_equal 4, Jdbc::Postgres.send(:jdbc_version)
    end

    test 'returns jdbc version 4.1 on java 7/8' do
      ENV_JAVA[ 'java.specification.version' ] = '1.7'
      assert_equal 4.1, Jdbc::Postgres.send(:jdbc_version)

      ENV_JAVA[ 'java.specification.version' ] = '1.8'
      assert_equal 4.1, Jdbc::Postgres.send(:jdbc_version)
    end

    context 'load-driver' do

      ROOT_DIR = File.expand_path('../../..', File.dirname(__FILE__))

      @@driver_dir = File.join(ROOT_DIR, 'jdbc-postgres/lib')

      test 'on java 6' do
        ENV_JAVA[ 'java.specification.version' ] = '1.6'
        Jdbc::Postgres.expects(:load).with do |driver_jar|
          assert_match /.jdbc4.jar$/, driver_jar
          full_path = File.join(@@driver_dir, driver_jar)
          assert File.exist?(full_path), "#{driver_jar.inspect} not found in: #{@@driver_dir.inspect}"
          true
        end
        Jdbc::Postgres.load_driver
      end

      test 'on java 7' do
        ENV_JAVA[ 'java.specification.version' ] = '1.7'
        Jdbc::Postgres.expects(:load).with do |driver_jar|
          assert_match /.jdbc41.jar$/, driver_jar
          full_path = File.join(@@driver_dir, driver_jar)
          assert File.exist?(full_path), "#{driver_jar.inspect} not found in: #{@@driver_dir.inspect}"
          true
        end
        Jdbc::Postgres.load_driver
      end

      test 'fails on java 5' do
        ENV_JAVA[ 'java.specification.version' ] = '1.5'
        Jdbc::Postgres.expects(:warn)
        assert_raise LoadError do
          Jdbc::Postgres.load_driver
        end
      end

    end

  end
end
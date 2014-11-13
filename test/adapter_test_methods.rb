require 'test_helper'

module AdapterTestMethods

  def test_visitor_accessor
    adapter = ActiveRecord::Base.connection; config = ActiveRecord::Base.connection_config
    assert_not_nil adapter.visitor
    assert_not_nil visitor_type = Arel::Visitors::VISITORS[ config[:adapter] ]
    assert_kind_of visitor_type, adapter.visitor
  end if Test::Unit::TestCase.ar_version('3.1') # >= 3.2

  def test_arel_visitors
    adapter = ActiveRecord::Base.connection; config = current_connection_config
    visitors = Arel::Visitors::VISITORS.dup
    assert_not_nil visitor_type = adapter.class.resolve_visitor_type(config)
    assert_equal visitor_type, visitors[ config[:adapter] ]
  end if Test::Unit::TestCase.ar_version('3.0') && defined? JRUBY_VERSION

  def test_instantiate_adapter
    config = current_connection_config
    adapter_class = if config.key?(:adapter_class) then config[:adapter_class]
    else
      if [ 'jdbc', 'jndi' ].include?( adapter = config[:adapter].to_s )
        ActiveRecord::ConnectionAdapters::JdbcAdapter
      else
        begin
          klass = :"#{adapter.capitalize}Adapter" # AR naming
          ActiveRecord::ConnectionAdapters.const_get(klass)
        rescue NameError
          ActiveRecord::ConnectionAdapters::JdbcAdapter
        end
      end
    end
    logger = ActiveRecord::Base.logger
    pool = ActiveRecord::Base.connection_pool
    connection_class = adapter_class.jdbc_connection_class(config[:adapter_spec])
    connection = silence_jdbc_connection_initialize { connection_class.new(config) }
    # ... e.g. ActiveRecord::ConnectionAdapters::MySQLJdbcConnection.new(config)

    if ar_version('3.2')
      adapter = adapter_class.new(connection, logger, pool)
      assert adapter.config
      assert_equal connection, adapter.raw_connection
      assert adapter.pool if ar_version('4.0')

      adapter = adapter_class.new(nil, logger, pool)
      # assert_equal config, adapter.config
      config.each do |key, val|
        assert_equal val, adapter.config[key]
      end
      assert_not_nil adapter.raw_connection
    end

    logger = ActiveRecord::Base.logger
    adapter = adapter_class.new(connection, logger)
    assert adapter.config
    assert_equal connection, adapter.raw_connection

    logger = ActiveRecord::Base.logger
    adapter = adapter_class.new(nil, logger)
    assert_not_nil adapter.raw_connection
  end if defined? JRUBY_VERSION

  private

  def silence_jdbc_connection_initialize(&block)
    warn = 'adapter not set, please pass adapter on JdbcConnection#initialize(config, adapter)'
    silence_warning(warn, &block)
  end

end
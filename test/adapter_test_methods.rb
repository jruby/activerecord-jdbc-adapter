require 'test_helper'

module AdapterTestMethods

  def test_instantiate_adapter
    config = current_connection_config
    adapter_class = config[:adapter_class] || ActiveRecord::ConnectionAdapters::JdbcAdapter
    logger = ActiveRecord::Base.logger
    pool = ActiveRecord::Base.connection_pool
    connection_class = adapter_class.jdbc_connection_class(config[:adapter_spec])
    connection =  deprecation_silence { connection_class.new(config) }
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

end
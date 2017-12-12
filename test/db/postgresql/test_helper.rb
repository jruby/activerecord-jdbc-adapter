require 'test_helper'

class Test::Unit::TestCase

  def enable_extension!(extension, connection)
    return false unless connection.supports_extensions?
    return connection.reconnect! if connection.extension_enabled?(extension)

    connection.enable_extension extension
    connection.commit_db_transaction
    connection.reconnect!
  end

  def disable_extension!(extension, connection)
    return false unless connection.supports_extensions?
    return true unless connection.extension_enabled?(extension)

    connection.disable_extension extension
    connection.reconnect!
  end

  def with_disabled_jdbc_driver_logging
    driver_logger = java.util.logging.Logger.getLogger('org.postgresql')
    return yield unless driver_logger

    original_level = driver_logger.getLevel
    begin
      driver_logger.setLevel(java.util.logging.Level::OFF)
      yield
    ensure
      driver_logger.setLevel(original_level)
    end
  end
  def with_disabled_jdbc_driver_logging; yield end unless defined? JRUBY_VERSION

end
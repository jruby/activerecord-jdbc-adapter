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

end
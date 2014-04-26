require File.expand_path('test_helper', File.dirname(__FILE__))
require 'row_locking_test_methods'

class DerbyRowLockingTest < Test::Unit::TestCase
  include RowLockingTestMethods

  private

  def thread_helper
    # will only work as expected when isolation is increased to serial :
    Entry.connection.raw_connection.transaction_isolation = :serializable

    yield
  rescue Exception => exc
    # Output backtrace, since otherwise we won't see anything until the main thread joins this thread.
    display_exception(exc)
    raise
  ensure
    # This is needed.  Otherwise, the database connections aren't returned to the pool and things break.
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end

end
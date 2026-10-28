require 'test_helper'
require 'db/postgres'

class PostgresDefaultTimezoneTest < Test::Unit::TestCase

  def setup
    @orig_tz = java.util.TimeZone.getDefault
    @orig_default = ActiveRecord.default_timezone
  end

  def teardown
    java.util.TimeZone.setDefault(@orig_tz)
    ActiveRecord.default_timezone = @orig_default
    connection.select_value('SELECT 1') # re-sync session zone
  end

  def test_session_zone_follows_default_timezone_at_runtime
    ActiveRecord.default_timezone = :utc
    assert_equal 'UTC', session_zone

    ActiveRecord.default_timezone = :local
    set_process_zone 'Asia/Tokyo'
    assert_equal 'Asia/Tokyo', session_zone

    # symbol stays :local, only the zone changes
    set_process_zone 'America/New_York'
    assert_equal 'America/New_York', session_zone

    ActiveRecord.default_timezone = :utc
    assert_equal 'UTC', session_zone
  end

  private

  def connection; ActiveRecord::Base.connection; end

  def session_zone; connection.select_value('SHOW TIME ZONE'); end

  def set_process_zone(id)
    java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone(id))
  end
end

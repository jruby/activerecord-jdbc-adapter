require 'test_helper'
require 'db/postgres_config'

ActiveRecord::Base.establish_connection(POSTGRES_CONFIG)

begin
  result = ActiveRecord::Base.connection.execute("SHOW server_version_num")
  PG_VERSION = result.first.first[1].to_i
rescue
  PG_VERSION = 0
end

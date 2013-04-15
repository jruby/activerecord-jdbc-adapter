# activerecord/test/cases/query_cache_test.rb requires this file
module SQLite3 # gem 'sqlite3' (native)
  module Version
    VERSION = '1.3.7' # SQLite3::Version::VERSION > '1.2.5'
  end
end
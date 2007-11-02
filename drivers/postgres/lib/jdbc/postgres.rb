module Jdbc
  module Postgres
    VERSION = "8.2" 
  end
end
require "postgresql-#{Jdbc::Postgres::VERSION}-504.jdbc3.jar"
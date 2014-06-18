require 'jdbc/postgresql/version'

module Jdbc
  PostgreSQL = Postgres unless const_defined?(:PostgreSQL)
end
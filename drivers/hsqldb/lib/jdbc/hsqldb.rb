module Jdbc
  module HSQLDB
    VERSION = "1.8.0.7"
  end
end
require "hsqldb-#{Jdbc::HSQLDB::VERSION}.jar"
module Jdbc
  module MySQL
    VERSION = "5.0.4"
  end
end
require "mysql-connector-java-#{Jdbc::MySQL::VERSION}-bin.jar"
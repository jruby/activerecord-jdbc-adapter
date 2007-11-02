module Jdbc
  module Derby
    VERSION = "10.2.2.0"
  end
end

require "derby-#{Jdbc::Derby::VERSION}.jar"
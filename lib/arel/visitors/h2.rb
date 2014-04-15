require 'arel/visitors/compat'
require 'arel/visitors/hsqldb'

module Arel
  module Visitors
    class H2 < Arel::Visitors::HSQLDB
    end
  end
end

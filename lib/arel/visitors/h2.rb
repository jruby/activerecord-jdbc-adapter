require 'arel/visitors/compat'
require 'arel/visitors/hsqldb'

module Arel
  module Visitors
    class H2 < Arel::Visitors::HSQLDB
      def visit_Arel_Nodes_SelectStatement(o, *)
        o.limit ||= Arel::Nodes::Limit.new(-1) if o.offset
        super
      end if ArJdbc::AR42
    end
  end
end

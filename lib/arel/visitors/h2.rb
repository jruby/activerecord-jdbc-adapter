require 'arel/visitors/compat'
require 'arel/visitors/hsqldb'

module Arel
  module Visitors
    class H2 < Arel::Visitors::HSQLDB
      def visit_Arel_Nodes_SelectStatement(o, *)
        o.limit ||= Arel::Nodes::Limit.new(-1) if o.offset
        super
      end if ArJdbc::AR42

      def limit_offset sql, o
        offset = o.offset || 0
        offset = offset.expr unless (offset.nil? || offset == 0)
        if limit = o.limit
          "SELECT LIMIT #{offset} #{limit_for(limit)} #{sql[7..-1]}"
        elsif offset > 0
          "SELECT LIMIT #{offset} -1 #{sql[7..-1]}" # removes "SELECT "
        else
          sql
        end
      end unless ArJdbc::AR42
    end
  end
end

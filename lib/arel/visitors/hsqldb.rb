require 'arel/visitors/compat'

module Arel
  module Visitors
    class HSQLDB < Arel::Visitors::ToSql
      def visit_Arel_Nodes_SelectStatement(o, *)
        o.limit ||= Arel::Nodes::Limit.new(0) if o.offset
        super
      end if ArJdbc::AR42

      def visit_Arel_Nodes_SelectStatement o, a = nil
        sql = limit_offset(o.cores.map { |x| do_visit_select_core x, a }.join, o)
        sql << " ORDER BY #{o.orders.map { |x| do_visit x, a }.join(', ')}" unless o.orders.empty?
        sql
      end unless ArJdbc::AR42

      private

      def limit_offset sql, o
        offset = o.offset || 0
        offset = offset.expr unless (offset.nil? || offset == 0)
        if limit = o.limit
          "SELECT LIMIT #{offset} #{limit_for(limit)} #{sql[7..-1]}"
        elsif offset > 0
          "SELECT LIMIT #{offset} 0 #{sql[7..-1]}" # removes "SELECT "
        else
          sql
        end
      end unless ArJdbc::AR42
    end
  end
end

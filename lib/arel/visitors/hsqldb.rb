require 'arel/visitors/compat'

module Arel
  module Visitors
    class HSQLDB < Arel::Visitors::ToSql

      def visit_Arel_Nodes_SelectStatement o
        sql = limit_offset(o.cores.map { |x| visit_Arel_Nodes_SelectCore x }.join, o)
        sql << " ORDER BY #{o.orders.map { |x| visit x }.join(', ')}" unless o.orders.empty?
        sql
      end

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
      end

    end
  end
end

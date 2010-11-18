module Arel
  module Visitors
    class DB2 < Arel::Visitors::ToSql
      def visit_Arel_Nodes_SelectStatement o
        add_limit_offset([o.cores.map { |x| visit_Arel_Nodes_SelectCore x }.join,
         ("ORDER BY #{o.orders.map { |x| visit x }.join(', ')}" unless o.orders.empty?),
        ].compact.join(' '), o)
      end

      def add_limit_offset(sql, o)
        limit, offset = o.limit, o.offset
        if limit && !offset
          if limit == 1
            sql << " FETCH FIRST ROW ONLY"
          else
            sql << " FETCH FIRST #{limit} ROWS ONLY"
          end
        elsif limit && offset
          sql.gsub!(/SELECT/i, 'SELECT B.* FROM (SELECT A.*, row_number() over () AS internal$rownum FROM (SELECT')
          sql << ") A ) B WHERE B.internal$rownum > #{offset} AND B.internal$rownum <= #{limit + offset}"
        end
        sql
      end
    end
  end
end

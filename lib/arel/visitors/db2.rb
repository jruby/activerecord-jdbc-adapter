# NOTE: file contains code adapted from **ruby-ibmdb**'s adapter, license follows
=begin
Copyright (c) 2006 - 2015 IBM Corporation

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
=end

require 'arel/visitors/compat'

module Arel
  module Visitors
    class DB2 < Arel::Visitors::ToSql

      if ArJdbc::AR42
        def visit_Arel_Nodes_SelectStatement(o, a = nil)
          a = o.cores.inject(a) { |c, x| visit_Arel_Nodes_SelectCore(x, c) }

          unless o.orders.empty?
            a << ' ORDER BY '
            last = o.orders.length - 1
            o.orders.each_with_index do |x, i|
              visit(x, a);  a << ', ' unless last == i
            end
          end

          if limit = o.limit
            if limit = limit.value
              limit = limit.to_i
            end
          end
          if offset = o.offset
            if offset = offset.value
              offset = offset.to_i
            end
          end

          if limit || offset
            add_limit_offset(a, o, limit, offset)
          else
            a
          end
        end

        def visit_Arel_Nodes_Limit o, collector
          # visit o.expr, collector
        end

        def visit_Arel_Nodes_Offset o, collector
          # visit o.expr, collector
        end

      else
        def visit_Arel_Nodes_SelectStatement o, a = nil
          sql = o.cores.map { |x| do_visit_select_core x, a }.join
          sql << " ORDER BY #{o.orders.map { |x| do_visit x, a }.join(', ')}" unless o.orders.empty?

          if limit = o.limit
            if limit = limit.value
              limit = limit.to_i
            end
          end
          if offset = o.offset
            if offset = offset.value
              offset = offset.to_i
            end
          end

          if limit || offset
            add_limit_offset(sql, o, limit, offset)
          else
            sql
          end
        end
      end

      if ArJdbc::AR42
        def visit_Arel_Nodes_InsertStatement o, a = nil
          a << "INSERT INTO "
          visit(o.relation, a)

          values = o.values

          if o.columns.any?
            cols = o.columns.map { |x| quote_column_name x.name }
            a << ' (' << cols.join(', ') << ') '
          elsif o.values.eql? ArJdbc::DB2::VALUES_DEFAULT
            cols = o.relation.engine.columns.map { |c| c.name }
            a << ' (' << cols.join(', ') << ')'
            a << ' VALUES '
            a << ' (' << cols.map { 'DEFAULT' }.join(', ') << ')'
            values = false
          end
          visit(values, a) if values
          a
        end
      elsif Arel::VERSION >= '4.0' # AR 4.0 ... AREL 5.0 since AR >= 4.1
        def visit_Arel_Nodes_InsertStatement o, a = nil
          sql = "INSERT INTO "
          sql << visit(o.relation, a)

          values = o.values

          if o.columns.any?
            cols = o.columns.map { |x| quote_column_name x.name }
            sql << ' (' << cols.join(', ') << ') '
          # should depend the other way around but who cares it's AR
          elsif o.values.eql? ArJdbc::DB2::VALUES_DEFAULT
            cols = o.relation.engine.columns.map { |c| c.name }
            sql << ' (' << cols.join(', ') << ')'
            sql << ' VALUES '
            sql << ' (' << cols.map { 'DEFAULT' }.join(', ') << ')'
            values = nil
          end

          sql << visit(values, a) if values

          sql
        end
      end

      private

      def add_limit_offset(sql, o, limit, offset)
        @connection.replace_limit_offset! sql, limit, offset, o.orders
      end

    end
  end
end

Arel::Collectors::Bind.class_eval do
  attr_reader :parts
end if defined? Arel::Collectors::Bind
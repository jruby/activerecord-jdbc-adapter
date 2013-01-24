module ArJdbc
  module Sybase
    def add_limit_offset!(sql, options) # :nodoc:
      @limit = options[:limit]
      @offset = options[:offset]
      if use_temp_table?
        # Use temp table to hack offset with Sybase
        sql.sub!(/ FROM /i, ' INTO #artemp FROM ')
      elsif zero_limit?
        # "SET ROWCOUNT 0" turns off limits, so we havesy
        # to use a cheap trick.
        if sql =~ /WHERE/i
          sql.sub!(/WHERE/i, 'WHERE 1 = 2 AND ')
        elsif sql =~ /ORDER\s+BY/i
          sql.sub!(/ORDER\s+BY/i, 'WHERE 1 = 2 ORDER BY')
        else
          sql << 'WHERE 1 = 2'
        end
      end
    end

    # If limit is not set at all, we can ignore offset;
    # if limit *is* set but offset is zero, use normal select
    # with simple SET ROWCOUNT.  Thus, only use the temp table
    # if limit is set and offset > 0.
    def use_temp_table?
      !@limit.nil? && !@offset.nil? && @offset > 0
    end

    def zero_limit?
      !@limit.nil? && @limit == 0
    end

    def modify_types(types) # :nodoc:
      super(types)
      types[:primary_key] = "NUMERIC(22,0) IDENTITY PRIMARY KEY"
      types[:integer][:limit] = nil
      types[:boolean] = {:name => "bit"}
      types[:binary] = {:name => "image"}
      types
    end

    def remove_index(table_name, options = {})
      execute "DROP INDEX #{table_name}.#{index_name(table_name, options)}"
    end
  end
end

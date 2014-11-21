require 'arjdbc/jdbc/date_time_support'

module ActiveRecord
  module ConnectionAdapters
    class MysqlAdapter
      class Column
        include ArJdbc::DateTimeSupport
      end
    end
  end
end

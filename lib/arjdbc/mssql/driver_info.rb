module ArJdbc
  module MSSQL
    module DriverInfo
      def sqlserver_driver?(config)
        config[:driver] =~ /SQLServerDriver$/ || config[:url] =~ /^jdbc:sqlserver:/
      end
      module_function :sqlserver_driver?
    end
  end
end


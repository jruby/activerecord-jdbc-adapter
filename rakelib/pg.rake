require File.expand_path '../../test/helper', __FILE__

module PostgresHelper
  def self.pg_cmdline_params
    params = ""
    params += "-h #{ENV['PGHOST']} " if ENV['PGHOST']
    params += "-p #{ENV['PGPORT']} " if ENV['PGPORT']
    params
  end

  def self.have_postgres?(warn = nil)
    if find_executable?("psql")
      if `psql -c '\\l' -U postgres #{pg_cmdline_params}2>&1` && $?.exitstatus == 0
        true
      else
        if warn.nil?
          warn = "No \"postgres\" role? You might need to execute `createuser postgres -drs' first."
        end
        send(:warn, warn) if warn # warn == false disables warnings
        false
      end
    end
  end
end

# Defining helper methods useful both in the definition of test tasks, as well as in the execution
# of tests themselves.  Do not require test/unit within this file, as that'll make the rake process
# attempt to run tests itself.  Test-specific helpers should go in test/jdbc_common.rb.

module Kernel
  def find_executable?(name)
    (ENV['PATH'] || '').split(File::PATH_SEPARATOR).
      detect { |p| File.executable?(File.join(p, name)) }
  end
end

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

require 'fileutils'

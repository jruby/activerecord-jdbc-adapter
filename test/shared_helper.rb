# Helpers useful both in the definition of test tasks, as well as in tests.

require 'fileutils'

module Kernel

  # Cross-platform way of finding an executable in the $PATH.
  # Thanks to @mislav
  #
  # which('ruby') #=> /usr/bin/ruby
  def which(cmd)
    exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
    ( ENV['PATH'] || '' ).split(File::PATH_SEPARATOR).each do |path|
      exts.each do |ext|
        exe = File.join(path, "#{cmd}#{ext}")
        return exe if File.executable? exe
      end
    end
    nil
  end

end

module PostgresHelper
  class << self
    def postgres_role?(warn = nil)
      if psql = which('psql')
        user = ENV['PGUSER'] || 'arjdbc'
        password = ENV['PGPASSWORD'] || 'arjdbc'
        host = ENV['PGHOST'] || 'localhost'
        port = ENV['PGPORT'] || '5432'
        
        # Use simpler command with explicit parameters
        cmd = "PGPASSWORD=#{password} #{psql} -h #{host} -p #{port} -d postgres -U #{user} -c '\\q' 2>&1"
        
        if `#{cmd}` && $?.exitstatus == 0
          true
        else
          if warn.nil?
            warn =  "No \"#{user}\" role ? Make sure service postgresql is running, "
            warn << "than you might need to execute `createuser #{user} -drs' first."
          end
          send(:warn, warn) if warn # warn == false disables warnings
          false
        end
      end
    end
    alias_method :have_postgres?, :postgres_role?

    private

    def psql_params
      params = ""
      params << "-h #{ENV['PGHOST']} " if ENV['PGHOST']
      params << "-p #{ENV['PGPORT']} " if ENV['PGPORT']
      params
    end
  end
end

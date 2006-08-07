
require 'fileutils'

from_d=File.expand_path(File.join(File.dirname(__FILE__),'lib','active_record'))
to_d=File.expand_path(File.join(RAILS_ROOT,'lib','active_record'))

FileUtils.cp_r from_d, to_d

env_file = File.expand_path(File.join(RAILS_ROOT,"config","environment.rb"))
bck_file = File.expand_path(File.join(RAILS_ROOT,"config","~.environment.rb.before_jdbc"))

FileUtils.mv env_file,bck_file

File.open(bck_file,"r") {|inf|
  File.open(env_file,"w") {|out|
    inf.each_line do |ln|
      if ln =~ /^Rails::Initializer\.run/
        out.puts "# Added by ActiveRecord JDBC plugin"
        out.puts "RAILS_CONNECTION_ADAPTERS = %w( jdbc mysql postgresql sqlite firebird sqlserver db2 oracle sybase openbase )"
        out.puts
      end
      out.puts ln
    end
  }
}

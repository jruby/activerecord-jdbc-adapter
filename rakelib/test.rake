require File.expand_path('../../test/helper', __FILE__)
if defined?(JRUBY_VERSION)
  databases = [:test_mysql, :test_jdbc, :test_sqlite3, :test_derby, :test_hsqldb, :test_h2]
  if find_executable?("psql") && `psql -c '\\l'` && $?.exitstatus == 0
    databases << :test_postgres
  end
  if File.exist?('test/fscontext.jar')
    databases << :test_jndi
  end
  task :test => databases
else
  task :test => [:test_mysql]
end

def declare_test_task_for(adapter, options = {})
  driver = options[:driver] || adapter
  Rake::TestTask.new("test_#{adapter}") do |t|
    files = FileList["test/#{adapter}*test.rb"]
    if adapter == "derby"
      files << 'test/activerecord/connection_adapters/type_conversion_test.rb'
    end
    t.test_files = files
    t.libs = []
    if defined?(JRUBY_VERSION)
      t.ruby_opts << "-rjdbc/#{driver}"
      t.libs << "lib" << "drivers/#{driver}/lib"
      t.libs.push *FileList["adapters/#{adapter}*/lib"]
    end
    t.libs << "test"
    t.verbose = true
  end
end

declare_test_task_for :derby
declare_test_task_for :h2
declare_test_task_for :hsqldb
declare_test_task_for :mssql, :driver => :jtds
declare_test_task_for :mysql
declare_test_task_for :postgres
declare_test_task_for :sqlite3

Rake::TestTask.new(:test_jdbc) do |t|
  t.test_files = FileList['test/generic_jdbc_connection_test.rb']
  t.libs << 'test' << 'drivers/mysql/lib'
end

Rake::TestTask.new(:test_jndi) do |t|
  t.test_files = FileList['test/jndi*_test.rb']
  t.libs << 'test' << 'drivers/derby/lib'
end

task :test_postgresql => [:test_postgres]
task :test_pgsql => [:test_postgres]

# Ensure driver for these DBs is on your classpath
%w(oracle db2 cachedb informix).each do |d|
  Rake::TestTask.new("test_#{d}") do |t|
    t.test_files = FileList["test/#{d}*_test.rb"]
    t.libs = []
    t.libs << 'lib' if defined?(JRUBY_VERSION)
    t.libs << 'test'
  end
end

# Tests for JDBC adapters that don't require a database.
Rake::TestTask.new(:test_jdbc_adapters) do | t |
  t.test_files = FileList[ 'test/jdbc_adapter/jdbc_sybase_test.rb' ]
  t.libs << 'test'
end

# Ensure that the jTDS driver is in your classpath before launching rake
Rake::TestTask.new(:test_sybase_jtds) do |t|
  t.test_files = FileList['test/sybase_jtds_simple_test.rb']
  t.libs << 'test' 
end

# Ensure that the jConnect driver is in your classpath before launching rake
Rake::TestTask.new(:test_sybase_jconnect) do |t|
  t.test_files = FileList['test/sybase_jconnect_simple_test.rb']
  t.libs << 'test' 
end

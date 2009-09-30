require File.dirname(__FILE__) + '/../test/helper'
if defined?(JRUBY_VERSION)
  databases = [:test_mysql, :test_jdbc, :test_derby, :test_hsqldb, :test_h2, :test_sqlite3]
  if find_executable?("psql") && `psql -c '\\l'` && $?.exitstatus == 0
    databases << :test_postgres
  end
  task :test => databases
else
  task :test => [:test_mysql]
end

FileList['drivers/*'].each do |d|
  next unless File.directory?(d)
  driver = File.basename(d)
  Rake::TestTask.new("test_#{driver}") do |t|
    files = FileList["test/#{driver}*test.rb"]
    if driver == "derby"
      files << 'test/activerecord/connection_adapters/type_conversion_test.rb'
    end
    t.test_files = files
    t.libs = []
    if defined?(JRUBY_VERSION)
      t.ruby_opts << "-rjdbc/#{driver}"
      t.libs << "lib" << "#{d}/lib"
      t.libs.push *FileList["adapters/#{driver}*/lib"]
    end
    t.libs << "test"
    t.verbose = true
  end
end

Rake::TestTask.new(:test_jdbc) do |t|
  t.test_files = FileList['test/generic_jdbc_connection_test.rb', 'test/jndi_callbacks_test.rb']
  t.libs << 'test' << 'drivers/mysql/lib'
end

Rake::TestTask.new(:test_jndi) do |t|
  t.test_files = FileList['test/jndi_test.rb']
  t.libs << 'test' << 'drivers/derby/lib'
end

task :test_postgresql => [:test_postgres]
task :test_pgsql => [:test_postgres]

# Ensure driver for these DBs is on your classpath
%w(oracle db2 cachedb mssql informix).each do |d|
  Rake::TestTask.new("test_#{d}") do |t|
    t.test_files = FileList["test/#{d}_simple_test.rb"]
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

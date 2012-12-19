require File.expand_path '../../test/helper', __FILE__
if defined?(JRUBY_VERSION)
  databases = [:test_mysql, :test_jdbc, :test_sqlite3, :test_derby, :test_hsqldb, :test_h2]
  databases << :test_postgres if PostgresHelper.have_postgres?(false)
  if File.exist?('test/fscontext.jar')
    databases << :test_jndi
  end
  task :test do
    unless PostgresHelper.have_postgres?
      warn "... won't run test_postgres tests"
    end
    databases.each { |task| Rake::Task[task.to_s].invoke }
  end
else
  task :test => [:test_mysql]
end

def set_compat_version(task)
  task.ruby_opts << '-v' if RUBY_VERSION =~ /1\.8/
  if defined?(JRUBY_VERSION)
    task.ruby_opts << "--#{RUBY_VERSION[/^(\d+\.\d+)/, 1]}"
  end
end

def all_appraisal_names
  @appraisal_names ||= begin names = []; Appraisal::File.each { |file| names << file.name }; names end
end

def declare_test_task_for(adapter, options = {})
  driver = options[:driver] || adapter
  prereqs = options[:prereqs] || []
  prereqs = [ prereqs ].flatten
  task "test_#{adapter}_pre" do
    puts "Specify AR version with 'rake appraisal:{version} test_#{adapter}' where version=(#{all_appraisal_names.join('|')})"
  end
  prereqs << "test_#{adapter}_pre"
  test_task = lambda do |t|
    task_name = t.name.keys.first
    files = FileList["test/#{adapter}*test.rb"]
    files.unshift "test/db/#{task_name.sub('test_','')}.rb"
    if adapter == "derby"
      files << 'test/activerecord/connection_adapters/type_conversion_test.rb'
    end
    t.test_files = files
    t.libs = []
    set_compat_version(t)
    if defined?(JRUBY_VERSION)
      t.ruby_opts << "-rjdbc/#{driver}"
      t.libs << "lib" << "jdbc-#{driver}/lib"
      t.libs.push *FileList["activerecord-jdbc#{adapter}*/lib"]
    end
    t.libs << "test"
    t.verbose = true
  end
  Rake::TestTask.new("test_#{adapter}" => prereqs) { |t| test_task.call t }
  Rake::TestTask.new("test_jdbc_#{adapter}" => prereqs) { |t| test_task.call t }
end

declare_test_task_for :derby
declare_test_task_for :h2
declare_test_task_for :hsqldb
declare_test_task_for :mssql, :driver => :jtds
declare_test_task_for :mysql, :prereqs => "db:mysql"
declare_test_task_for :postgres, :prereqs => "db:postgres"
declare_test_task_for :sqlite3

Rake::TestTask.new(:test_jdbc) do |t|
  t.test_files = FileList['test/generic_jdbc_connection_test.rb']
  t.libs << 'test' << 'jdbc-mysql/lib'
  set_compat_version(t)
end

Rake::TestTask.new(:test_jndi) do |t|
  Rake::Task['tomcat-jndi:check'].invoke
  t.test_files = FileList['test/jndi_test.rb']
  t.libs << 'test' << 'jdbc-derby/lib'
  set_compat_version(t)
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
    set_compat_version(t)
  end
end

# Tests for JDBC adapters that don't require a database.
Rake::TestTask.new(:test_jdbc_adapters) do | t |
  t.test_files = FileList[ 'test/jdbc_adapter/jdbc_sybase_test.rb' ]
  t.libs << 'test'
  set_compat_version(t)
end

# Ensure that the jTDS driver is in your classpath before launching rake
Rake::TestTask.new(:test_sybase_jtds) do |t|
  t.test_files = FileList['test/sybase_jtds_simple_test.rb']
  t.libs << 'test'
  set_compat_version(t)
end

# Ensure that the jConnect driver is in your classpath before launching rake
Rake::TestTask.new(:test_sybase_jconnect) do |t|
  t.test_files = FileList['test/sybase_jconnect_simple_test.rb']
  t.libs << 'test'
  set_compat_version(t)
end

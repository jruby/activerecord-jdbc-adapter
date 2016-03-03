require File.expand_path('../../test/shared_helper', __FILE__)

test_tasks = [ 'test_mysql', 'test_sqlite3', 'test_postgresql_with_hint' ]
if defined?(JRUBY_VERSION)
  test_tasks.push :test_derby, :test_hsqldb, :test_h2
  test_tasks.push :test_jndi, :test_jdbc
end

desc "Run \"most\" available test_xxx tasks"
task :test => test_tasks

task 'test_postgresql_with_hint' do
  if PostgresHelper.have_postgres?(false)
    Rake::Task['test_postgresql'].invoke
  else
    puts "NOTE: won't run test_postgresql"
  end
end

task 'test_appraisal_hint' do
  next if File.exists?('.disable-appraisal-hint')
  unless (ENV['BUNDLE_GEMFILE'] || '') =~ /gemfiles\/.*?\.gemfile/
    appraisals = []; Appraisal::File.each { |file| appraisals << file.name }
    puts "HINT: specify AR version with `rake appraisal:{version} test_{adapter}'" +
         " where version=(#{appraisals.join('|')}) (`touch .disable-appraisal-hint' to disable)"
  end
end

Rake::TestTask.class_eval { attr_reader :test_files }

def test_task_for(adapter, options = {})
  desc = options[:desc] || options[:comment] ||
    "Run tests against #{options[:database_name] || adapter}"
  adapter = adapter.to_s.downcase
  driver = adapter if ( driver = options[:driver] ).nil?
  prereqs = options[:prereqs] || []
  unless prereqs.frozen?
    prereqs = [ prereqs ].flatten; prereqs << 'test_appraisal_hint'
  end
  name = options[:name] || "test_#{adapter}"
  test_task = Rake::TestTask.new(name => prereqs) do |test_task|
    files = options[:files] || begin
      FileList["test/#{adapter}*_test.rb"] +
        FileList["test/db/#{adapter}/**/*_test.rb"]
    end
    test_task.test_files = files
    test_task.libs = []
    if defined?(JRUBY_VERSION)
      test_task.libs << 'lib'
      test_task.libs << "jdbc-#{driver}/lib" if driver && File.exists?("jdbc-#{driver}/lib")
      test_task.libs.push *FileList["activerecord-jdbc#{adapter}*/lib"]
    end
    test_task.libs << 'test'
    test_task.ruby_opts << '-v' if RUBY_VERSION.index('1.8') == 0
    # set current Ruby compatibility version on JRuby <= 1.7 :
    if defined?(JRUBY_VERSION) && JRUBY_VERSION.index('1.7') == 0
      test_task.ruby_opts << "--#{RUBY_VERSION[/^(\d+\.\d+)/, 1]}"
    end
    test_task.options = '--use-color=t'
    test_task.verbose = true if $VERBOSE
    yield(test_task) if block_given?
  end
  task = Rake::Task[name]
  # reset the description set-up by Rake::TestTask :
  if task.instance_variable_defined? :@full_comment
    task.instance_variable_set(:@full_comment, nil)
  else
    task.instance_variable_get(:@comments).clear
  end
  task.add_description(desc)
  test_task
end

test_task_for :Derby, :desc => 'Run tests against (embedded) DerbyDB'
test_task_for :H2, :desc => 'Run tests against H2 database engine'
test_task_for :HSQLDB, :desc => 'Run tests against HyperSQL (Java) database'
test_task_for :MSSQL, :driver => :jtds, :database_name => 'MS-SQL (SQLServer)'
test_task_for :MySQL, :prereqs => 'db:mysql'
test_task_for :PostgreSQL, :driver => 'postgres', :prereqs => 'db:postgresql'
task :test_postgres => :test_postgresql # alias
test_task_for :SQLite3, :driver => ENV['JDBC_SQLITE_VERSION']
task :test_sqlite => :test_sqlite3 # alias
test_task_for :Firebird

test_task_for :MariaDB, :prereqs => 'db:mysql', :files => FileList["test/db/mysql/*_test.rb"]

# ensure driver for these DBs is on your class-path
[ :Oracle, :DB2, :Informix, :CacheDB ].each do |adapter|
  test_task_for adapter, :desc => "Run tests against #{adapter} (ensure driver is on class-path)"
end

#test_task_for :MSSQL, :name => 'test_sqlserver', :driver => nil, :database_name => 'MS-SQL using SQLJDBC'

test_task_for :AS400, :desc => "Run tests against AS400 (DB2) (ensure driver is on class-path)",
  :files => FileList["test/db2*_test.rb"] + FileList["test/db/db2/*_test.rb"]

test_task_for 'JDBC', :desc => 'Run tests against plain JDBC adapter (uses MySQL and Derby)',
  :prereqs => 'db:mysql', :files => FileList['test/*jdbc_*test.rb'] do |test_task|
  test_task.libs << 'jdbc-mysql/lib' << 'jdbc-derby/lib'
end

test_task_for 'JNDI', :desc => 'Run tests against a JNDI connection (uses Derby)',
  :prereqs => 'tomcat-jndi:check',
  :files => FileList['test/*jndi_*test.rb'] do |test_task|
  test_task.libs << 'jdbc-derby/lib'
end

test_task_for :MySQL, :name => 'test_jdbc_mysql',
  :prereqs => 'db:mysql', :database_name => 'MySQL (using adapter: jdbc)' do |test_task|
  test_task.ruby_opts << '-rdb/jdbc_mysql' # replaces require 'db/mysql'
end
test_task_for :PostgreSQL, :name => 'test_jdbc_postgresql', :driver => 'postgres',
  :prereqs => 'db:postgresql', :database_name => 'PostgreSQL (using adapter: jdbc)' do |test_task|
  test_task.ruby_opts << '-rdb/jdbc_postgres' # replaces require 'db/postgres'
end

# TODO Sybase testing is currently broken, please fix it if you're on Sybase :
#test_task_for :Sybase, :desc => "Run tests against Sybase (using jTDS driver)"
#task :test_sybase_jtds => :test_sybase # alias
#test_task_for :Sybase, :name => 'sybase_jconnect',
#  :desc => "Run tests against Sybase (ensure jConnect driver is on class-path)"

require File.expand_path('../../test/shared_helper', __FILE__)

if defined?(JRUBY_VERSION)
  databases = [ :test_mysql, :test_sqlite3, :test_derby, :test_hsqldb, :test_h2 ]
  databases << :test_postgres if PostgresHelper.have_postgres?(false)
  databases << :test_jdbc ; databases << :test_jndi
  task :test do
    unless PostgresHelper.have_postgres?
      warn "... won't run test_postgres tests"
    end
    databases.each { |task| Rake::Task[task.to_s].invoke }
  end
else
  task :test => [ :test_mysql ]
end

def set_compat_version(task)
  task.ruby_opts << '-v' if RUBY_VERSION =~ /1\.8/
  if defined?(JRUBY_VERSION)
    task.ruby_opts << "--#{RUBY_VERSION[/^(\d+\.\d+)/, 1]}"
  end
end

%w(derby h2 hsqldb mysql sqlite3 postgres mssql oracle db2 informix sybase).each do 
  |adapter| 
  task "test_#{adapter}_pre" do
    unless (ENV['BUNDLE_GEMFILE'] rescue '') =~ /gemfiles\/.*?\.gemfile/
      appraisals = []; Appraisal::File.each { |file| appraisals << file.name }
      puts "Specify AR version with `rake appraisal:{version} test_#{adapter}'" + 
           " where version=(#{appraisals.join('|')})"
    end
  end  
end

Rake::TestTask.class_eval { attr_reader :test_files }

def declare_test_task_for(adapter, options = {}, &block)
  driver = options[:driver] || adapter
  prereqs = options[:prereqs] || []
  prereqs = [ prereqs ].flatten
  prereqs << "test_#{adapter}_pre"
  Rake::TestTask.new("test_#{adapter}" => prereqs) do |task|
    files = FileList["test/#{adapter}*_test.rb"]
    files += FileList["test/db/#{adapter}/*_test.rb"]
    #task_name = task.name.keys.first.to_s
    #files.unshift "test/db/#{task_name.sub('test_','')}.rb"
    task.test_files = files
    task.libs = []
    if defined?(JRUBY_VERSION)
      task.libs << "lib" << "jdbc-#{driver}/lib"
      task.libs.push *FileList["activerecord-jdbc#{adapter}*/lib"]
    end
    task.libs << "test"
    set_compat_version(task)
    task.verbose = true if $VERBOSE    
    yield(task) if block_given?
  end
end

declare_test_task_for :derby do |task|
  task.test_files << 'test/activerecord/connection_adapters/type_conversion_test.rb'
end
declare_test_task_for :h2
declare_test_task_for :hsqldb
declare_test_task_for :mssql, :driver => :jtds
declare_test_task_for :mysql, :prereqs => "db:mysql"
declare_test_task_for :postgres, :prereqs => "db:postgres"
task :test_postgresql => :test_postgres # alias
task :test_pgsql => :test_postgres # alias
declare_test_task_for :sqlite3

# ensure driver for these DBs is on your class-path
[ :oracle, :db2, :informix, :cachedb ].each do |adapter|
  Rake::TestTask.new("test_#{adapter}") do |task|
    test_files = FileList["test/#{adapter}*_test.rb"]
    test_files += FileList["test/db/#{adapter}/*_test.rb"]
    task.test_files = test_files
    task.libs = []
    task.libs << 'lib' if defined?(JRUBY_VERSION)
    task.libs << 'test'
    set_compat_version(task)
  end
end

Rake::TestTask.new(:test_jdbc) do |t|
  t.test_files = FileList['test/*jdbc_*test.rb']
  t.libs << 'test' << 'jdbc-mysql/lib' << 'jdbc-derby/lib'
  set_compat_version(t)
end

Rake::TestTask.new(:test_jndi => 'tomcat-jndi:check') do |t|
  t.test_files = FileList['test/*jndi_*test.rb']
  t.libs << 'test' << 'jdbc-derby/lib'
  set_compat_version(t)
end

# tests for JDBC adapters that don't require a database :
Rake::TestTask.new(:test_jdbc_adapters) do |task|
  task.test_files = FileList[ 'test/jdbc_adapter/jdbc_sybase_test.rb' ]
  task.libs << 'test'
  set_compat_version(task)
end

# ensure that the jTDS driver is in your class-path
Rake::TestTask.new(:test_sybase_jtds) do |task|
  task.test_files = FileList['test/sybase_jtds_simple_test.rb']
  task.libs << 'test'
  set_compat_version(task)
end

# ensure that the jConnect driver is in your class-path
Rake::TestTask.new(:test_sybase_jconnect) do |task|
  task.test_files = FileList['test/sybase_jconnect_simple_test.rb']
  task.libs << 'test'
  set_compat_version(task)
end

Rake::TraceOutput.module_eval do

  # NOTE: avoid TypeError: String can't be coerced into Fixnum
  # due this method gettings a strings == [ 1 ] argument ...
  def trace_on(out, *strings)
    sep = $\ || "\n"
    if strings.empty?
      output = sep
    else
      output = strings.map { |s|
        next if s.nil?; s = s.to_s
        s =~ /#{sep}$/ ? s : s + sep
      }.join
    end
    out.print(output)
  end
  
end
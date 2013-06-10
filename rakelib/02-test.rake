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

def set_test_task_compat_version(task)
  task.ruby_opts << '-v' if RUBY_VERSION =~ /1\.8/
  if defined?(JRUBY_VERSION)
    task.ruby_opts << "--#{RUBY_VERSION[/^(\d+\.\d+)/, 1]}"
  end
end

def set_task_description(task, desc)
  unless task.is_a?(Rake::Task)
    task = task.name if task.is_a?(Rake::TestTask)
    task = Rake::Task[task]
  end
  # reset the desc set-up by TestTask :
  task.instance_variable_set(:@full_comment, nil)
  task.add_description(desc)
end

%w(derby h2 hsqldb mysql sqlite3 postgres mssql oracle db2 as400 informix sybase).each do
  |adapter| task "test_#{adapter}_pre" do
    next if File.exists?('.disable-appraisal-hint')
    unless (ENV['BUNDLE_GEMFILE'] rescue '') =~ /gemfiles\/.*?\.gemfile/
      appraisals = []; Appraisal::File.each { |file| appraisals << file.name }
      puts "HINT: specify AR version with `rake appraisal:{version} test_#{adapter}'" +
           " where version=(#{appraisals.join('|')}) (`touch .disable-appraisal-hint' to disable)"
    end
  end
end

Rake::TestTask.class_eval { attr_reader :test_files }

def test_task_for(adapter, options = {})
  desc = options[:desc] || options[:comment] ||
    "Run tests against #{options[:database_name] || adapter}"
  adapter = adapter.to_s.downcase
  driver = options[:driver] || adapter
  prereqs = [ options[:prereqs] || [] ].flatten
  prereqs << "test_#{adapter}_pre"
  name = options[:name] || "test_#{adapter}"
  test_task = Rake::TestTask.new(name => prereqs) do |test_task|
    files = options[:files] || begin
      FileList["test/#{adapter}*_test.rb"] +
        FileList["test/db/#{adapter}/*_test.rb"]
    end
    test_task.test_files = files
    test_task.libs = []
    if defined?(JRUBY_VERSION)
      test_task.libs << 'lib'
      test_task.libs << "jdbc-#{driver}/lib" if File.exists?("jdbc-#{driver}/lib")
      test_task.libs.push *FileList["activerecord-jdbc#{adapter}*/lib"]
    end
    test_task.libs << 'test'
    set_test_task_compat_version test_task
    test_task.verbose = true if $VERBOSE
    yield(test_task) if block_given?
  end
  set_task_description name, desc
  test_task
end

test_task_for :Derby, :desc => 'Run tests against (embedded) DerbyDB'
test_task_for :H2, :desc => 'Run tests against H2 database engine'
test_task_for :HSQLDB, :desc => 'Run tests against HyperSQL (Java) database'
test_task_for :MSSQL, :driver => :jtds, :database_name => 'MS-SQL (SQLServer)'
test_task_for :MySQL, :prereqs => 'db:mysql'
test_task_for :PostgreSQL, :prereqs => 'db:postgres'
task :test_postgres => :test_postgresql # alias
task :test_pgsql => :test_postgresql # alias
test_task_for :SQLite3

# ensure driver for these DBs is on your class-path
[ :Oracle, :DB2, :Informix, :CacheDB ].each do |adapter|
  test_task_for adapter, :desc => "Run tests against #{adapter} (ensure driver is on class-path)"
end

test_task_for :AS400, :desc => "Run tests against AS400 (DB2) (ensure driver is on class-path)",
  :files => FileList["test/db2*_test.rb"] + FileList["test/db/db2/*_test.rb"]

test_task_for 'JDBC', :desc => 'Run tests against plain JDBC adapter (uses MySQL and Derby)',
  :files => FileList['test/*jdbc_*test.rb'] do |test_task|
  test_task.libs << 'jdbc-mysql/lib' << 'jdbc-derby/lib'
end

test_task_for 'JNDI', :desc => 'Run tests against a JNDI connection (uses Derby)',
  :prereqs => 'tomcat-jndi:check',
  :files => FileList['test/*jndi_*test.rb'] do |test_task|
  test_task.libs << 'jdbc-derby/lib'
end

# TODO Sybase testing is currently broken, please fix it if you're on Sybase :
#test_task_for :Sybase, :desc => "Run tests against Sybase (using jTDS driver)"
#task :test_sybase_jtds => :test_sybase # alias
#test_task_for :Sybase, :name => 'sybase_jconnect',
#  :desc => "Run tests against Sybase (ensure jConnect driver is on class-path)"

Rake::TraceOutput.module_eval do

  # NOTE: avoid TypeError: String can't be coerced into Fixnum
  # due this method getting some strings == [ 1 ] argument ...
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
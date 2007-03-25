require 'rake'
require 'rake/testtask'

task :default => :test

def java_classpath_arg # myriad of ways to discover JRuby classpath
  begin
    require 'java' # already running in a JRuby JVM
    jruby_cpath = Java::java.lang.System.getProperty('java.class.path')
  rescue LoadError
  end
  unless jruby_cpath
    jruby_cpath = ENV['JRUBY_PARENT_CLASSPATH'] || ENV['JRUBY_HOME'] &&
      FileList["#{ENV['JRUBY_HOME']}/lib/*.jar"].join(File::PATH_SEPARATOR)
  end
  cpath_arg = jruby_cpath ? "-cp #{jruby_cpath}" : ""
end

task :java_compile do
  mkdir_p "pkg/classes"
  sh "javac -d pkg/classes #{java_classpath_arg} #{FileList['src/java/**/*.java'].join(' ')}"
  sh "jar cf lib/jdbc_adapter_internal.jar -C pkg/classes/ ."
end

task :more_clean do
  rm_rf FileList['derby*']
  rm_rf FileList['test.db.*']
  rm_rf "test/reports"
  rm_f FileList['lib/*.jar']
end

task :clean => :more_clean

task :filelist do
  puts FileList['pkg/**/*'].inspect
end

desc "Run AR-JDBC tests"
if RUBY_PLATFORM =~ /java/
  task :test => [:java_compile, :test_mysql, :test_hsqldb, :test_derby]
else
  task :test => [:test_mysql]
end

Rake::TestTask.new(:test_mysql) do |t|
  t.test_files = FileList['test/mysql_simple_test.rb']
  t.libs << 'test'
end

Rake::TestTask.new(:test_hsqldb) do |t|
  t.test_files = FileList['test/hsqldb_simple_test.rb']
  t.libs << 'test'
end

Rake::TestTask.new(:test_derby) do |t|
  t.test_files = FileList['test/derby_simple_test.rb', 
    'test/activerecord/connection_adapters/type_conversion_test.rb']
  t.libs << 'test'
end

Rake::TestTask.new(:test_postgresql) do |t|
  t.test_files = FileList['test/postgres_simple_test.rb']
  t.libs << 'test'
end

task :test_pgsql => [:test_postgresql]

Rake::TestTask.new(:test_jndi) do |t|
  t.test_files = FileList['test/jndi_test.rb']
  t.libs << 'test'
end

begin
  require 'hoe'

  MANIFEST = FileList["History.txt", "Manifest.txt", "README.txt", 
    "Rakefile", "LICENSE", "lib/**/*.rb", "lib/**/*.jar", "test/**/*.rb"]

  Hoe.new("ActiveRecord-JDBC", "0.2.3") do |p|
    p.rubyforge_name = "jruby-extras"
    p.url = "http://jruby-extras.rubyforge.org/ActiveRecord-JDBC"
    p.author = "Nick Sieger, Ola Bini and JRuby contributors"
    p.email = "nick@nicksieger.com, ola.bini@ki.se"
    p.summary = "JDBC adapter for ActiveRecord, for use within JRuby on Rails."
    p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
    p.description = p.paragraphs_of('README.txt', 0...1).join("\n\n")
    p.extra_deps.reject!{|d| d.first == "hoe"}
  end.spec.files = MANIFEST

  # Automated manifest
  task :manifest do
    File.open("Manifest.txt", "w") {|f| MANIFEST.each {|n| f << "#{n}\n"} }
  end

  task :package => [:manifest, :java_compile]
rescue LoadError
  # Install hoe in order to make a release
  # puts e.inspect
end

require 'rake'
require 'rake/testtask'

task :default => [:java_compile, :test]

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

desc "Compile the native Java code."
task :java_compile do
  mkdir_p "pkg/classes"
  sh "javac -target 1.4 -source 1.4 -d pkg/classes #{java_classpath_arg} #{FileList['src/java/**/*.java'].join(' ')}"
  sh "jar cf lib/jdbc_adapter_internal.jar -C pkg/classes/ ."
end
file "lib/jdbc_adapter_internal.jar" => :java_compile

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
  # TODO: add more databases into the standard tests here.
  task :test => [:test_mysql, :test_jdbc, :test_derby, :test_hsqldb]
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
    t.ruby_opts << "-r#{driver}"
    t.test_files = files
    t.libs << "test" << "#{d}/lib"
  end
end

Rake::TestTask.new(:test_jdbc) do |t|
  t.test_files = FileList['test/generic_jdbc_connection_test.rb']
  t.libs << 'test' << 'drivers/mysql/lib'
end

Rake::TestTask.new(:test_jndi) do |t|
  t.test_files = FileList['test/jndi_test.rb']
  t.libs << 'test' << 'drivers/derby/lib'
end

task :test_postgresql => [:test_postgres]
task :test_pgsql => [:test_postgres]

MANIFEST = FileList["History.txt", "Manifest.txt", "README.txt", 
  "Rakefile", "LICENSE", "lib/**/*.rb", "lib/jdbc_adapter_internal.jar", "test/**/*.rb",
   "lib/**/*.rake", "src/**/*.java"]

file "Manifest.txt" => :manifest
task :manifest do
  File.open("Manifest.txt", "w") {|f| MANIFEST.each {|n| f << "#{n}\n"} }
end
Rake::Task['manifest'].invoke # Always regen manifest, so Hoe has up-to-date list of files

require File.dirname(__FILE__) + "/lib/jdbc_adapter/version"
begin
  require 'hoe'
  Hoe.new("activerecord-jdbc-adapter", JdbcAdapter::Version::VERSION) do |p|
    p.rubyforge_name = "jruby-extras"
    p.url = "http://jruby-extras.rubyforge.org/activerecord-jdbc-adapter"
    p.author = "Nick Sieger, Ola Bini and JRuby contributors"
    p.email = "nick@nicksieger.com, ola.bini@gmail.com"
    p.summary = "JDBC adapter for ActiveRecord, for use within JRuby on Rails."
    p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
    p.description = p.paragraphs_of('README.txt', 0...1).join("\n\n")
    p.extra_deps << ['activerecord', ">= 1.14"]
  end.spec.dependencies.delete_if { |dep| dep.name == "hoe" }
rescue LoadError
  puts "You really need Hoe installed to be able to package this gem"
rescue => e
  puts "ignoring error while loading hoe: #{e.to_s}"
end

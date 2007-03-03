require 'rake'
require 'rake/testtask'

task :default => :test

desc "Run AR-JDBC tests"
if RUBY_PLATFORM =~ /java/
  task :test => [:test_mysql, :test_hsqldb, :test_derby]
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

begin
  require 'hoe'

  MANIFEST = FileList["History.txt", "Manifest.txt", "README.txt", 
    "Rakefile", "LICENSE", "lib/**/*.rb", "test/**/*.rb"]

  Hoe.new("ActiveRecord-JDBC", "0.2.3") do |p|
    p.rubyforge_name = "jruby-extras"
    p.url = "http://jruby-extras.rubyforge.org/ActiveRecord-JDBC"
    p.author = "Nick Sieger, Ola Bini and JRuby contributors"
    p.email = "nick@nicksieger.com, ola.bini@ki.se"
    p.summary = "JDBC adapter for ActiveRecord, for use within JRuby on Rails."
    p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
    p.description = p.paragraphs_of('README.txt', 0...1).join("\n\n")
    p.extra_deps.reject!{|d| d.first == "hoe"}
    p.spec_extras = {:autorequire => "jdbc_adapter"}
  end.spec.files = MANIFEST

  # Automated manifest
  task :manifest do
    File.open("Manifest.txt", "w") {|f| MANIFEST.each {|n| f << "#{n}\n"} }
  end

  task :package => :manifest
rescue => e
  # Install hoe in order to make a release
  # puts e.inspect
end

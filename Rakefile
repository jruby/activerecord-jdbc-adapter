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
  t.test_files = FileList['test/activerecord/connection_adapters/type_conversion_test.rb']
  t.libs << 'test'
end

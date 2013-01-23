require 'rake/testtask'
require 'rake/clean'
CLEAN.include 'derby*', 'test.db.*','test/reports', 'test.sqlite3','lib/**/*.jar','manifest.mf', '*.log'

require 'bundler/gem_helper'
Bundler::GemHelper.install_tasks

require 'bundler/setup'
require 'appraisal'

task :default => [:jar, :test]

#ugh, bundler doesn't use tasks, so gotta hook up to both tasks.
task :build => :jar
task :install => :jar

ADAPTERS = %w[derby h2 hsqldb mssql mysql postgresql sqlite3].map { |a| "activerecord-jdbc#{a}-adapter" }
DRIVERS  = %w[derby h2 hsqldb jtds mysql postgres sqlite3].map { |a| "jdbc-#{a}" }
TARGETS = ( ADAPTERS + DRIVERS )

def rake(*args)
  ruby "-S", "rake", *args
end

TARGETS.each do |target|
  namespace target do
    task :build do
      Dir.chdir(target) { rake "build" }
      cp FileList["#{target}/pkg/#{target}-*.gem"], "pkg"
    end
    task :install do
      Dir.chdir(target) { rake "install" }
    end
    task :release do
      Dir.chdir(target) { rake "release" }
    end
  end
end

# DRIVERS

desc "Build drivers"
task "drivers:build" => DRIVERS.map { |name| "#{name}:build" }

desc "Install drivers"
task "drivers:install" => DRIVERS.map { |name| "#{name}:install" }

desc "Release drivers"
task "drivers:release" => DRIVERS.map { |name| "#{name}:release" }

# ADAPTERS

desc "Build adapters"
task "adapters:build" => [ 'build' ] + ADAPTERS.map { |name| "#{name}:build" }

desc "Install adapters"
task "adapters:install" => [ 'install' ] + ADAPTERS.map { |name| "#{name}:install" }

desc "Release adapters"
task "adapters:release" => [ 'release' ] + ADAPTERS.map { |name| "#{name}:release" }

# ALL

task "all:build" => [ 'build' ] + TARGETS.map { |name| "#{name}:build" }
task "all:install" => [ 'install' ] + TARGETS.map { |name| "#{name}:install" }

task :filelist do
  puts FileList['pkg/**/*'].inspect
end

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

ADAPTERS = %w[derby h2 hsqldb mssql mysql postgresql sqlite3].map {|a| "activerecord-jdbc#{a}-adapter" }
DRIVERS  = %w[derby h2 hsqldb mysql postgres sqlite3].map {|a| "jdbc-#{a}" }

# Only include jtds driver if compiling on Java 7
begin
  java_version = Java::JavaLang::System.get_property( "java.specification.version" )
  java_version = java_version.split( '.' ).map { |v| v.to_i }
  if ( ( java_version <=> [ 1, 7 ] ) >= 0 )
    DRIVERS << "jdbc-jtds"
  end
end

TARGETS = (ADAPTERS+DRIVERS)

def rake(*args)
  ruby "-S", "rake", *args
end

TARGETS.each do |target|
  namespace target do

    task :build do
      Dir.chdir(target) do
        rake "build"
      end
      cp FileList["#{target}/pkg/#{target}-*.gem"], "pkg"
    end

    # bundler handles install => build itself
    task :install do
      Dir.chdir(target) do
        rake "install"
      end
    end

    task :release do
      Dir.chdir(target) do
        rake "release"
      end
    end
  end
end

{"all" => TARGETS, "adapters" => ADAPTERS, "drivers" => DRIVERS}.each_pair do |name, targets|
  desc "Release #{name}"
  task "#{name}:release" => ["release", *targets.map { |f| "#{f}:release" }]

  desc "Install #{name}"
  task "#{name}:install" => ["install", *targets.map { |f| "#{f}:install" }]

  desc "Build #{name}"
  task "#{name}:build"   => ["build", *targets.map { |f| "#{f}:build" }]
end

task :filelist do
  puts FileList['pkg/**/*'].inspect
end

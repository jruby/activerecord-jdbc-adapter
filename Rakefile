require 'rake/testtask'
require 'rake/clean'
CLEAN.include 'derby*', 'test.db.*','test/reports', 'test.sqlite3','lib/**/*.jar','manifest.mf', '*.log'

require 'bundler'
Bundler::GemHelper.install_tasks
require 'bundler/setup'

task :default => [:jar, :test]

#ugh, bundler doesn't use tasks, so gotta hook up to both tasks.
task :build => :jar
task :install => :jar

ADAPTERS = %w[derby h2 hsqldb mssql mysql postgresql sqlite3].map {|a| "activerecord-jdbc#{a}-adapter" }
DRIVERS  = %w[derby h2 hsqldb jtds mysql postgres sqlite3].map {|a| "jdbc-#{a}" }

def rake(args)
  ruby "-S", "rake", *args
end

(ADAPTERS + DRIVERS).each do |adapter|
  namespace adapter do

    task :build do
      Dir.chdir(adapter) do
        rake "build"
      end
      cp FileList["#{adapter}/pkg/#{adapter}-*.gem"], "pkg"
    end

    # bundler handles install => build itself
    task :install do
      Dir.chdir(adapter) do
        rake "install"
      end
    end

    task :release do
      Dir.chdir(adapter) do
        rake "release"
      end
    end
  end
end

desc "Release all adapters"
task "all:release" => ["release", *ADAPTERS.map { |f| "#{f}:release" }]

desc "Install all adapters"
task "all:install" => ["install", *ADAPTERS.map { |f| "#{f}:install" }]

desc "Build all adapters"
task "all:build"   => ["build", *ADAPTERS.map { |f| "#{f}:build" }]

task :filelist do
  puts FileList['pkg/**/*'].inspect
end


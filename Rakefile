require 'rake/testtask'

require 'rake/clean'
CLEAN.include 'derby*', 'test.db.*', '*test.sqlite3', 'test/reports'
CLEAN.include 'lib/**/*.jar', 'MANIFEST.MF', '*.log', 'target/*'

require 'bundler/gem_helper'
Bundler::GemHelper.install_tasks

require 'bundler/setup'
require 'appraisal'

task :default => [:jar, :test]

task :build => :jar
task :install => :jar

ADAPTERS = %w[derby h2 hsqldb mssql mysql postgresql sqlite3].map { |a| "activerecord-jdbc#{a}-adapter" }
DRIVERS  = %w[derby h2 hsqldb jtds mysql postgres sqlite3].map { |a| "jdbc-#{a}" }
TARGETS = ( ADAPTERS + DRIVERS )

rake = lambda { |task| ruby "-S", "rake", task }
current_version = lambda { Bundler.load_gemspec('activerecord-jdbc-adapter.gemspec').version }

ADAPTERS.each do |target|
  namespace target do
    task :build do
      version = current_version.call
      Dir.chdir(target) { rake.call "build" }
      cp FileList["#{target}/pkg/#{target}-#{version}.gem"], "pkg"
    end
  end
end
DRIVERS.each do |target|
  namespace target do
    task :build do
      Dir.chdir(target) { rake.call "build" }
      cp FileList["#{target}/pkg/#{target}-*.gem"], "pkg"
    end
  end
end
TARGETS.each do |target|
  namespace target do
    task :install do
      Dir.chdir(target) { rake.call "install" }
    end
    task :release do
      Dir.chdir(target) { rake.call "release" }
    end
  end
end

# DRIVERS

desc "Build drivers"
task "build:drivers" => DRIVERS.map { |name| "#{name}:build" }
task "drivers:build" => 'build:drivers'

desc "Install drivers"
task "install:drivers" => DRIVERS.map { |name| "#{name}:install" }
task "drivers:install" => 'install:drivers'

# desc "Release drivers"
# task "release:drivers" => DRIVERS.map { |name| "#{name}:release" }
# task "drivers:release" => DRIVERS.map { |name| "#{name}:release" }

# ADAPTERS

desc "Build adapters"
task "build:adapters" => [ 'build' ] + ADAPTERS.map { |name| "#{name}:build" }
task "adapters:build" => 'build:adapters'

desc "Install adapters"
task "install:adapters" => [ 'install' ] + ADAPTERS.map { |name| "#{name}:install" }
task "adapters:install" => 'install:adapters'

desc "Release adapters"
task "release:adapters" => [ 'release' ] + ADAPTERS.map { |name| "#{name}:release" }
task "adapters:release" => 'release:adapters'

task 'release:do' => 'build:adapters' do
  version = current_version.call; version_tag = "v#{version}"

  sh("git diff --no-patch --exit-code") { |ok| fail "git working dir is not clean" unless ok }
  sh("git diff-index --quiet --cached HEAD") { |ok| fail "git index is not clean" unless ok }

  sh "git tag -a -m \"AR-JDBC #{version}\" #{version_tag}"
  branch = `git rev-parse --abbrev-ref HEAD`.strip
  puts "releasing from (current) branch #{branch.inspect}"
  sh "for gem in `ls pkg/*-#{version}.gem`; do gem push $gem; done" do |ok|
    sh "git push origin #{branch} --tags" if ok
  end
end

# ALL

task "build:all" => [ 'build' ] + TARGETS.map { |name| "#{name}:build" }
task "all:build" => 'build:all'
task "install:all" => [ 'install' ] + TARGETS.map { |name| "#{name}:install" }
task "all:install" => 'install:all'

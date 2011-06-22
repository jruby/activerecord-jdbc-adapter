require 'rake/testtask'
require 'rake/clean'
CLEAN.include 'derby*', 'test.db.*','test/reports', 'test.sqlite3','lib/**/*.jar','manifest.mf', '*.log'

require 'bundler'
Bundler::GemHelper.install_tasks

task :default => [:java_compile, :test]

#ugh, bundler doesn't use tasks, so gotta hook up to both tasks.
task :build => :java_compile
task :install => :java_compile

ADAPTERS = %w[derby h2 hsqldb mssql mysql postgresql sqlite3].map {|a| "activerecord-jdbc#{a}-adapter" }

root    = File.expand_path("..", __FILE__)
version = File.read("#{root}/ARJDBC_VERSION").strip

def rake(args)
  ruby "-S", "rake", *args
end

ADAPTERS.each do |adapter|
  namespace adapter do

    task :build do
      Dir.chdir(adapter) do
        rake "build"
      end
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


namespace :all do
  desc "Build all adapters"
  task :build   => ADAPTERS.map { |f| "#{f}:build"       }

  desc "Install all adapters"
  task :install => ADAPTERS.map { |f| "#{f}:install"     }

  desc "Release all adapters"
  task :release    => ADAPTERS.map { |f| "#{f}:release"  }
end

task :filelist do
  puts FileList['pkg/**/*'].inspect
end


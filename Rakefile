require 'rubygems' unless defined? Gem

require 'rake/clean'

CLEAN.include 'derby*', 'test.db.*', '*test.sqlite3', 'test/reports'
CLEAN.include 'MANIFEST.MF', '*.log'

task :default => :jar # RubyGems extention will do a bare `rake' e.g. :
# jruby" -rubygems /opt/local/rvm/gems/jruby-1.7.16@jdbc/gems/rake-10.3.2/bin/rake
#   RUBYARCHDIR=/opt/local/rvm/gems/jruby-1.7.16@jdbc/gems/activerecord-jdbc-adapter-1.4.0.dev/lib
#   RUBYLIBDIR=/opt/local/rvm/gems/jruby-1.7.16@jdbc/gems/activerecord-jdbc-adapter-1.4.0.dev/lib

# ugh, bundler doesn't use tasks, so gotta hook up to both tasks.
task :build => :jar
task :install => :jar

ADAPTERS = %w[derby h2 hsqldb mssql mysql postgresql sqlite3].map { |a| "activerecord-jdbc#{a}-adapter" }
DRIVERS  = %w[derby h2 hsqldb jtds mysql postgres sqlite3].map { |a| "jdbc-#{a}" }
TARGETS = ( ADAPTERS + DRIVERS )

rake = lambda { |task| ruby "-S", "rake", task }
get_version = lambda { Bundler.load_gemspec('activerecord-jdbc-adapter.gemspec').version }

TARGETS.each do |target|
  namespace target do
    task :build do
      Dir.chdir(target) { rake.call "build" }
      cp FileList["#{target}/pkg/#{target}-*.gem"], "pkg"
    end
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
  version = get_version.call; version_tag = "v#{version}"

  sh("git diff --no-patch --exit-code") { |ok| fail "git working dir is not clean" unless ok }
  sh("git diff-index --quiet --cached HEAD") { |ok| fail "git index is not clean" unless ok }

  sh "git tag -a -m \"AR-JDBC #{version}\" #{version_tag}"
  sh "for gem in `ls pkg/*-#{version}.gem`; do gem push $gem; done" do |ok|
    sh "git push origin master --tags" if ok
  end
end

task 'release:push' do
  sh "for gem in `ls pkg/*-#{get_version.call}.gem`; do gem push $gem; done"
end

# ALL

task "build:all" => [ 'build' ] + TARGETS.map { |name| "#{name}:build" }
task "all:build" => 'build:all'
task "install:all" => [ 'install' ] + TARGETS.map { |name| "#{name}:install" }
task "all:install" => 'install:all'

begin # allow to roll without Bundler
  require 'bundler/gem_helper'
  Bundler::GemHelper.install_tasks
rescue LoadError
end

require 'rake/testtask'

begin
  require 'appraisal'
rescue LoadError
  begin
    require 'bundler/setup'
    require 'appraisal'
  rescue LoadError
  end
end

# JRuby extension compilation :

if defined? JRUBY_VERSION
  jar_file = 'lib/arjdbc/jdbc/adapter_java.jar'; CLEAN << jar_file
  desc "Compile the native (Java) extension."
  task :jar => jar_file

  namespace :jar do
    task :force do
      rm jar_file if File.exist?(jar_file)
      Rake::Task['jar'].invoke
    end
  end

  directory classes = 'pkg/classes'; CLEAN << classes

  file jar_file => FileList[ classes, 'src/java/**/*.java' ] do
    source = target = '1.6'; debug = true
    args = [ '-Xlint:unchecked' ]

    Dir.mktmpdir do |classes_dir|
      driver_jars = []
      driver_jars << Dir.glob("jdbc-postgres/lib/*.jar").sort.last
      driver_jars << Dir.glob("jdbc-mysql/lib/*.jar").last
      if driver_jars.empty? # likely on a `gem install ...'
        # TODO
      end

      classpath = []
      classpath += ENV_JAVA['java.class.path'].split(File::PATH_SEPARATOR)
      classpath += ENV_JAVA['sun.boot.class.path'].split(File::PATH_SEPARATOR)
      classpath.push *driver_jars
      classpath = classpath.compact.join(File::PATH_SEPARATOR)

      source_files = FileList[ 'src/java/**/*.java' ]

      javac = "javac -target #{target} -source #{source} #{args.join(' ')}"
      javac << " #{debug ? '-g' : ''}"
      javac << " -cp \"#{classpath}\" -d #{classes_dir} #{source_files.join(' ')}"
      sh javac

      # class_files = FileList["#{classes_dir}/**/*.class"].gsub("#{classes_dir}/", '')
      # avoid environment variable expansion using backslash
      # class_files.gsub!('$', '\$') unless windows?
      # args = class_files.map { |path| [ "-C #{classes_dir}", path ] }.flatten
      args = [ '-C', "#{classes_dir}/ ." ] # args = class_files

      jar_path = jar_file.sub('lib', ENV['RUBYLIBDIR'] || 'lib')

      sh "jar cf #{jar_path} #{args.join(' ')}"
    end
  end
else
  task :jar do
    puts "Run 'jar' with JRuby to re-compile the agent extension class"
  end
end
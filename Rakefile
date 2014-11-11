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

    classpath = []
    classpath += ENV_JAVA['java.class.path'].split(File::PATH_SEPARATOR)
    classpath += ENV_JAVA['sun.boot.class.path'].split(File::PATH_SEPARATOR)

    compile_driver_deps = [ :Postgres, :MySQL ]

    driver_jars = []
    #compile_driver_deps.each do |name|
    #  driver_jars << Dir.glob("jdbc-#{name.to_s.downcase}/lib/*.jar").sort.last
    #end
    if driver_jars.empty? # likely on a `gem install ...'
      # NOTE: we're currently assuming jdbc-xxx (compile) dependencies are
      # installed, they are declared as gemspec.development_dependencies !
      # ... the other option is to simply `mvn prepare-package'
      compile_driver_deps.each do |name|
        #require "jdbc/#{name.to_s.downcase}"
        #driver_jars << Jdbc.const_get(name).driver_jar
        # thanks Bundler for mocking RubyGems completely :
        #spec = Gem::Specification.find_by_name("jdbc-#{name.to_s.downcase}")
        #driver_jars << Dir.glob(File.join(spec.gem_dir, 'lib/*.jar')).sort.last
        gem_name = "jdbc-#{name.to_s.downcase}"; matched_gem_paths = []
        Gem.paths.path.each do |path|
          base_path = File.join(path, "gems/")
          Dir.glob(File.join(base_path, "*")).each do |gem_path|
            if gem_path.sub(base_path, '').start_with?(gem_name)
              matched_gem_paths << gem_path
            end
          end
        end
        if gem_path = matched_gem_paths.sort.last
          driver_jars << Dir.glob(File.join(gem_path, 'lib/*.jar')).sort.last
        end
      end
    end

    classpath.push *driver_jars
    classpath = classpath.compact.join(File::PATH_SEPARATOR)

    source_files = FileList[ 'src/java/**/*.java' ]

    require 'tmpdir'
    
    Dir.mktmpdir do |classes_dir|

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
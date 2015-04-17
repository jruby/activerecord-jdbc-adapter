require 'rubygems' unless defined? Gem

require 'rake/clean'

CLEAN.include 'derby*', 'test.db.*', '*test.sqlite3', 'test/reports'
CLEAN.include 'MANIFEST.MF', '*.log'

task :default => :jar # RubyGems extention will do a bare `rake' e.g. :
# jruby" -rubygems /opt/local/rvm/gems/jruby-1.7.16@jdbc/gems/rake-10.3.2/bin/rake
#   RUBYARCHDIR=/opt/local/rvm/gems/jruby-1.7.16@jdbc/gems/activerecord-jdbc-adapter-1.4.0.dev/lib
#   RUBYLIBDIR=/opt/local/rvm/gems/jruby-1.7.16@jdbc/gems/activerecord-jdbc-adapter-1.4.0.dev/lib

base_dir = Dir.pwd
gem_name = 'activerecord-jdbc-adapter'
gemspec_path = File.expand_path('activerecord-jdbc-adapter.gemspec', File.dirname(__FILE__))
gemspec = lambda do
  @_gemspec_ ||= Dir.chdir(File.dirname(__FILE__)) do
    Gem::Specification.load(gemspec_path)
  end
end
built_gem_path = lambda do
  Dir[File.join(base_dir, "#{gem_name}-*.gem")].sort_by{ |f| File.mtime(f) }.last
end
current_version = lambda { gemspec.call.version }
rake = lambda { |task| ruby "-S", "rake", task }

# NOTE: avoid Bundler loading due native extension building!

desc "Build #{gem_name} gem into the pkg directory."
task :build => :jar do
  sh("gem build -V '#{gemspec_path}'") do
    gem_path = built_gem_path.call
    file_name = File.basename(gem_path)
    FileUtils.mkdir_p(File.join(base_dir, 'pkg'))
    FileUtils.mv(gem_path, 'pkg')
    puts "\n#{gem_name} #{current_version.call} built to 'pkg/#{file_name}'"
  end
end

desc "Build and install #{gem_name} gem into system gems."
task :install => :build do
  gem_path = built_gem_path.call
  sh("gem install '#{gem_path}' --local") do |ok|
    raise "Couldn't install gem, run `gem install #{gem_path}' for more detailed output" unless ok
    puts "\n#{gem_name} (#{current_version.call}) installed"
  end
end

task 'release:do' => 'build:adapters' do
  ENV['RELEASE'] == 'true' # so that .gemspec is built with adapter_java.jar
  Rake::Task['build'].invoke

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

task 'release:push' do
  sh "for gem in `ls pkg/*-#{current_version.call}.gem`; do gem push $gem; done"
end

ADAPTERS = %w[derby h2 hsqldb mssql mysql postgresql sqlite3].map { |a| "activerecord-jdbc#{a}-adapter" }
DRIVERS  = %w[derby h2 hsqldb jtds mysql postgres sqlite3].map { |a| "jdbc-#{a}" }
TARGETS = ( ADAPTERS + DRIVERS )

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

# ADAPTERS

desc "Build adapters"
task "build:adapters" => [ 'build' ] + ADAPTERS.map { |name| "#{name}:build" }
task "adapters:build" => 'build:adapters'

desc "Install adapters"
task "install:adapters" => [ 'install' ] + ADAPTERS.map { |name| "#{name}:install" }
task "adapters:install" => 'install:adapters'

# ALL

task "build:all" => [ 'build' ] + TARGETS.map { |name| "#{name}:build" }
task "all:build" => 'build:all'
task "install:all" => [ 'install' ] + TARGETS.map { |name| "#{name}:install" }
task "all:install" => 'install:all'

require 'rake/testtask'

begin
  require 'appraisal'
rescue LoadError; end

# native JRuby extension (adapter_java.jar) compilation :

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

    get_driver_jars_local = lambda do |*args|
      driver_deps = args.empty? ? [ :Postgres, :MySQL ] : args
      driver_jars = []
      driver_deps.each do |name|
        driver_jars << Dir.glob("jdbc-#{name.to_s.downcase}/lib/*.jar").sort.last
      end
      if driver_jars.empty? # likely on a `gem install ...'
        # NOTE: we're currently assuming jdbc-xxx (compile) dependencies are
        # installed, they are declared as gemspec.development_dependencies !
        # ... the other option is to simply `mvn prepare-package'
        driver_deps.each do |name|
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
      driver_jars
    end

    get_driver_jars_maven = lambda do
      require 'jar_dependencies'

      requirements = gemspec.call.requirements
      match_driver_jars = lambda do
        matched_jars = []
        gemspec.call.requirements.each do |requirement|
          if match = requirement.match(/^jar\s+([\w\-\.]+):([\w\-]+),\s+?([\w\.\-]+)?/)
            matched_jar = Jars.send :to_jar, match[1], match[2], match[3], nil
            matched_jar = File.join( Jars.home, matched_jar )

            matched_jars << matched_jar if File.exists?( matched_jar )
          end
        end
        matched_jars
      end

      driver_jars = match_driver_jars.call
      if driver_jars.size < requirements.size
        if (ENV['JARS_SKIP'] || ENV_JAVA['jars.skip']) == 'true'
          warn "resolving jars is skipped, extension might not compile"
        else
          require 'jars/installer'
          installer = Jars::Installer.new( gemspec_path )
          installer.install_jars( false )
          driver_jars = match_driver_jars.call
        end
      end

      driver_jars
    end

    driver_jars = get_driver_jars_maven.call
    driver_jars = get_driver_jars_local.call

    classpath = []
    [ 'java.class.path', 'sun.boot.class.path' ].each do |key|
      classpath += ENV_JAVA[key].split(File::PATH_SEPARATOR).find_all { |jar| jar =~ /jruby/i }
    end
    #classpath += ENV_JAVA['java.class.path'].split(File::PATH_SEPARATOR)
    #classpath += ENV_JAVA['sun.boot.class.path'].split(File::PATH_SEPARATOR)

    classpath += driver_jars
    classpath = classpath.compact.join(File::PATH_SEPARATOR)

    source_files = FileList[ 'src/java/**/*.java' ]

    require 'tmpdir'

    Dir.mktmpdir do |classes_dir|
      # Cross-platform way of finding an executable in the $PATH.
      # Thanks to @mislav
      which = lambda do |cmd|
        exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
        ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
          exts.each do |ext|
            exe = File.join(path, "#{cmd}#{ext}")
            return exe if File.executable? exe
          end
        end
        nil
      end
      unless javac = which.call('javac')
        warn "could not find javac, please make sure it's on the PATH"
      end
      javac = "#{javac} -target #{target} -source #{source} #{args.join(' ')}"
      javac << " #{debug ? '-g' : ''}"
      javac << " -cp \"#{classpath}\" -d #{classes_dir} #{source_files.join(' ')}"
      sh(javac) do |ok|
        raise 'could not build .jar extension - compilation failure' unless ok
      end

      # class_files = FileList["#{classes_dir}/**/*.class"].gsub("#{classes_dir}/", '')
      # avoid environment variable expansion using backslash
      # class_files.gsub!('$', '\$') unless windows?
      # args = class_files.map { |path| [ "-C #{classes_dir}", path ] }.flatten
      args = [ '-C', "#{classes_dir}/ ." ] # args = class_files

      jar_path = jar_file.sub('lib', ENV['RUBYLIBDIR'] || 'lib')

      unless jar = which.call('jar')
        warn "could not find jar tool, please make sure it's on the PATH"
      end
      sh("#{jar} cf #{jar_path} #{args.join(' ')}") do |ok|
        raise 'could not build .jar extension - packaging failure' unless ok
      end
    end
  end
else
  task :jar do
    puts "Run 'jar' with JRuby to re-compile the agent extension class"
  end
end

jar_file = File.join(*%w(lib arjdbc jdbc adapter_java.jar))
begin
  require 'ant'
  directory classes = "pkg/classes"
  CLEAN << classes

  driver_jars = []
  # PostgreSQL driver :
  driver_jars << Dir.glob("jdbc-postgres/lib/*.jar").sort.last
  
  file jar_file => FileList['src/java/**/*.java', 'pkg/classes'] do
    rm_rf FileList["#{classes}/**/*"]
    ant.javac :srcdir => "src/java", :destdir => "pkg/classes",
      :source => "1.6", :target => "1.6", :debug => true, :deprecation => true,
      :classpath => "${java.class.path}:${sun.boot.class.path}:#{driver_jars.join(':')}",
      :includeantRuntime => false

    ant.tstamp do |ts|
      ts.format(:property => 'TODAY', :pattern => 'yyyy-MM-dd HH:mm:ss')
    end
    
    require 'arjdbc/version'
    gem_version = Gem::Version.create(ArJdbc::VERSION)
    if gem_version.segments.last == 'DEV'
      version = gem_version.segments[0...-1] # 1.3.0.DEV -> 1.3.0
    else
      version = gem_version.segments.dup
    end
    version = version.join('.')
    
    ant.manifest :file => 'MANIFEST.MF' do |mf|
      mf.attribute :name => 'Built-By', :value => '${user.name}'
      mf.attribute :name => 'Built-Time', :value => '${TODAY}'
      mf.attribute :name => 'Built-Jdk', :value => '${java.version}'
      mf.attribute :name => 'Built-JRuby', :value => JRUBY_VERSION
      
      mf.attribute :name => 'Specification-Title', :value => 'ActiveRecord-JDBC'
      mf.attribute :name => 'Specification-Version', :value => '1.3'
      mf.attribute :name => 'Specification-Vendor', :value => 'JRuby'
      mf.attribute :name => 'Implementation-Version', :value => version
      mf.attribute :name => 'Implementation-Vendor', :value => 'The JRuby Team'
    end
    
    ant.jar :basedir => "pkg/classes", :includes => "**/*.class", 
            :destfile => jar_file, :manifest => 'MANIFEST.MF'
  end

  desc "Compile the native Java code."
  task :jar => jar_file
  
  namespace :jar do
    task :force do
      rm jar_file if File.exist?(jar_file)
      Rake::Task['jar'].invoke
    end
  end
  
rescue LoadError
  task :jar do
    puts "Run 'jar' with JRuby to re-compile the agent extension class"
  end
end

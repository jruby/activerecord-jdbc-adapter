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

    ant.jar :basedir => "pkg/classes", :destfile => jar_file, :includes => "**/*.class"
  end

  desc "Compile the native Java code."
  task :jar => jar_file
  
  namespace :jar do
    task :force do
      rm jar_file
      Rake::Task['jar'].invoke
    end
  end
  
rescue LoadError
  task :jar do
    puts "Run 'jar' with JRuby to re-compile the agent extension class"
  end
end

jar_file = File.join(*%w(lib arjdbc jdbc adapter_java.jar))
begin
  require 'ant'
  directory classes = "pkg/classes"
  CLEAN << classes

  file jar_file => FileList['src/java/**/*.java', 'pkg/classes'] do
    rm_rf FileList["#{classes}/**/*"]
    ant.javac :srcdir => "src/java", :destdir => "pkg/classes",
      :source => "1.5", :target => "1.5", 
      :debug => true, :deprecation => true,
      :classpath => "${java.class.path}:${sun.boot.class.path}",
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

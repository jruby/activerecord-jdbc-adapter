jar_file = File.join(*%w(lib arjdbc jdbc adapter_java.jar))
begin
  require 'ant'
  directory "pkg/classes"
  CLEAN << "pkg"

  file jar_file => FileList['src/java/**/*.java', 'pkg/classes'] do
    rm_rf FileList['pkg/classes/**/*']
    ant.javac :srcdir => "src/java", :destdir => "pkg/classes",
      :source => "1.5", :target => "1.5", :debug => true,
      :classpath => "${java.class.path}:${sun.boot.class.path}",
      :includeantRuntime => false

    ant.jar :basedir => "pkg/classes", :destfile => jar_file, :includes => "**/*.class"
  end

  desc "Compile the native Java code."
  task :jar => jar_file
rescue LoadError
  task :jar do
    puts "Run 'jar' with JRuby to re-compile the agent extension class"
  end
end

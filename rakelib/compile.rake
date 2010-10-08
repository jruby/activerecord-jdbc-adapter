def java_classpath_arg # myriad of ways to discover JRuby classpath
  begin
    cpath  = Java::java.lang.System.getProperty('java.class.path').split(File::PATH_SEPARATOR)
    cpath += Java::java.lang.System.getProperty('sun.boot.class.path').split(File::PATH_SEPARATOR)
    jruby_cpath = cpath.compact.join(File::PATH_SEPARATOR)
  rescue => e
  end
  unless jruby_cpath
    jruby_cpath = ENV['JRUBY_PARENT_CLASSPATH'] || ENV['JRUBY_HOME'] &&
      FileList["#{ENV['JRUBY_HOME']}/lib/*.jar"].join(File::PATH_SEPARATOR)
  end
  jruby_cpath ? "-cp \"#{jruby_cpath}\"" : ""
end

jar_name = File.join(*%w(lib arjdbc jdbc adapter_java.jar))

desc "Compile the native Java code."
task :java_compile do
  debug = ENV['DEBUG'] ? '-g' : ''
  pkg_classes = File.join(*%w(pkg classes))
  mkdir_p pkg_classes
  sh "javac -target 1.5 -source 1.5 #{debug} -d pkg/classes #{java_classpath_arg} #{FileList['src/java/**/*.java'].join(' ')}"
  sh "jar cf #{jar_name} -C #{pkg_classes} ."
end
file jar_name => :java_compile

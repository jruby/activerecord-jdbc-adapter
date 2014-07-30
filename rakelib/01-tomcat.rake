namespace :'tomcat-jndi' do # contains a FS JNDI impl (for tests)

  TOMCAT_MAVEN_REPO = 'http://repo2.maven.org/maven2/org/apache/tomcat'
  TOMCAT_VERSION = '7.0.54'

  DOWNLOAD_DIR = File.expand_path('../test/jars', File.dirname(__FILE__))

  #tomcat_jar = "tomcat-embed-core.jar"
  #tomcat_uri = "#{TOMCAT_MAVEN_REPO}/embed/tomcat-embed-core/#{TOMCAT_VERSION}/tomcat-embed-core-#{TOMCAT_VERSION}.jar"

  catalina_jar = "tomcat-catalina.jar"
  catalina_uri = "#{TOMCAT_MAVEN_REPO}/tomcat-catalina/#{TOMCAT_VERSION}/tomcat-catalina-#{TOMCAT_VERSION}.jar"

  juli_jar = "tomcat-juli.jar"
  juli_uri = "#{TOMCAT_MAVEN_REPO}/tomcat-juli/#{TOMCAT_VERSION}/tomcat-juli-#{TOMCAT_VERSION}.jar"

  task :download do
    require 'open-uri'; require 'tmpdir'

    temp_dir = File.join(Dir.tmpdir, (Time.now.to_f * 1000).to_i.to_s)
    FileUtils.mkdir temp_dir

    downloads = Hash.new
    downloads[juli_jar] = juli_uri
    downloads[catalina_jar] = catalina_uri

    Dir.chdir(temp_dir) do
      FileUtils.mkdir DOWNLOAD_DIR unless File.exist?(DOWNLOAD_DIR)
      downloads.each do |jar, uri|
        puts "downloading #{uri}"
        file = open(uri)
        FileUtils.cp file.path, File.join(DOWNLOAD_DIR, jar)
      end
    end

    FileUtils.rm_r temp_dir
  end

  task :check do
    jar_path = File.join(DOWNLOAD_DIR, catalina_jar)
    unless File.exist?(jar_path)
      Rake::Task['tomcat-jndi:download'].invoke
    end
  end

  task :clear do
    jar_path = File.join(DOWNLOAD_DIR, catalina_jar)
    rm jar_path if File.exist?(jar_path)
  end

end
# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name = 'activerecord-jdbc-adapter'
  path = File.expand_path('lib/arjdbc/version.rb', File.dirname(__FILE__))
  gem.version = File.read(path).match( /.*VERSION\s*=\s*['"](.*)['"]/m )[1]
  gem.platform = 'java' # due jar-dependencies to resolve requirements for ext
  gem.authors = ['Nick Sieger, Ola Bini, Karol Bucek and JRuby contributors']
  gem.email = ['nick@nicksieger.com', 'ola.bini@gmail.com', 'self@kares.org']
  gem.homepage = 'https://github.com/jruby/activerecord-jdbc-adapter'
  gem.license = 'BSD-2-Clause'
  gem.summary = 'JDBC adapter for ActiveRecord, for use within JRuby on Rails.'
  gem.description = "" <<
    "AR-JDBC is a database adapter for Rails' ActiveRecord component designed " <<
    "to be used with JRuby built upon Java's JDBC API for database access. " <<
    "Provides (ActiveRecord) built-in adapters: MySQL, PostgreSQL and SQLite3 " <<
    "as well as adapters for popular databases such as Oracle, SQLServer, " <<
    "DB2, FireBird and even Java (embed) databases: Derby, HSQLDB and H2. " <<
    "It allows to connect to virtually any JDBC-compliant database with your " <<
    "JRuby on Rails application."

  gem.require_paths = ["lib"]

  gem.files = `git ls-files`.split("\n").
    reject { |f| f =~ /^(activerecord-jdbc[^-]|jdbc-)/ }. # gem directories
    reject { |f| f =~ /^(bench|test)/ }. # not sure if including tests is useful
    reject { |f| f =~ /^(gemfiles)/ } # no tests - no Gemfile_s appraised ...
  gem.files += ['lib/arjdbc/jdbc/adapter_java.jar'] #if ENV['RELEASE'].eql?('true')

  if ENV['INCLUDE_JAR_IN_GEM'] != 'true' # @see Rakefile
    gem.extensions << 'Rakefile' # to support auto-building .jar with :git paths

    #gem.add_runtime_dependency 'jar-dependencies', '~> 0.1' # development not enough!
    #gem.add_development_dependency 'ruby-maven', '~> 3.1'
    #
    #gem.requirements << "jar mysql:mysql-connector-java, 5.1.44, :scope => :compile"
    #gem.requirements << "jar org.postgresql:postgresql, 42.1.4.jre6, :scope => :compile"

    # compilation .jar dependencies for extension (at least until `mvn') :
    gem.add_development_dependency 'jdbc-mysql', '~> 5.1.44'
    gem.add_development_dependency 'jdbc-postgres', '~> 42.1'
  end

  gem.executables = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files = gem.files.grep(%r{^test/})

  gem.add_dependency 'activerecord', '~> 5.0.0', '>= 5.0.3'

  #gem.add_development_dependency 'test-unit', '2.5.4'
  #gem.add_development_dependency 'test-unit-context', '>= 0.3.0'
  #gem.add_development_dependency 'mocha', '~> 0.13.1'

  gem.rdoc_options = ["--main", "README.md", "-SHN", "-f", "darkfish"]
end


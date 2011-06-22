# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
version = File.read(File.expand_path("ARJDBC_VERSION")).strip
Gem::Specification.new do |s|
  s.name        = "activerecord-jdbc-adapter"
  s.version     = version
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Nick Sieger, Ola Bini and JRuby contributors"]
  s.email       = %q{nick@nicksieger.com, ola.bini@gmail.com}
  s.homepage = %q{http://jruby-extras.rubyforge.org/activerecord-jdbc-adapter}
  s.summary = %q{JDBC adapter for ActiveRecord, for use within JRuby on Rails.}
  s.description = %q{activerecord-jdbc-adapter is a database adapter for Rails' ActiveRecord
component that can be used with JRuby[http://www.jruby.org/]. It allows use of
virtually any JDBC-compliant database with your JRuby on Rails application.}
  s.files         = `git ls-files | grep -v activerecord-jdbc[^-]`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{|f| File.basename(f) }
  s.require_paths = ["lib"]
  s.rdoc_options = ["--main", "README.txt", "-SHN", "-f", "darkfish"]
  s.rubyforge_project = %q{jruby-extras}

  # s.add_dependency 'activerecord', "3.1.0.rc4"
end


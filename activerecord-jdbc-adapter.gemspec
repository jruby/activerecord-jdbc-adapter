# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'arjdbc/version'
version = ArJdbc::Version::VERSION
Gem::Specification.new do |s|
  s.name        = "activerecord-jdbc-adapter"
  s.version     = version
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Nick Sieger, Ola Bini and JRuby contributors"]
  s.email       = %q{nick@nicksieger.com, ola.bini@gmail.com}
  s.homepage = %q{https://github.com/jruby/activerecord-jdbc-adapter}
  s.summary = %q{JDBC adapter for ActiveRecord, for use within JRuby on Rails.}
  s.description = %q{activerecord-jdbc-adapter is a database adapter for Rails\' ActiveRecord
component that can be used with JRuby[http://www.jruby.org/]. It allows use of
virtually any JDBC-compliant database with your JRuby on Rails application.}
  s.license     = "BSD"
  s.files         = `git ls-files`.split("\n").reject {|v| v =~ /^(activerecord-jdbc[^-]|jdbc-)/}
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{|f| File.basename(f) }
  s.require_paths = ["lib"]
  s.rdoc_options = ["--main", "README.md", "-SHN", "-f", "darkfish"]
  s.rubyforge_project = %q{jruby-extras}
end


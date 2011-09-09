# -*- encoding: utf-8 -*-

$LOAD_PATH << File.expand_path('../lib', __FILE__)
require 'jdbc/derby'
version = Jdbc::Derby::VERSION
Gem::Specification.new do |s|
  s.name = %q{jdbc-derby}
  s.version = version

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Nick Sieger, Ola Bini and JRuby contributors"]
  s.date = %q{2010-10-12}

  s.description = %q{Install this gem and require 'derby' within JRuby to load the driver.}
  s.email = %q{nick@nicksieger.com, ola.bini@gmail.com}
  s.files = [
    "Rakefile", "README.txt", "LICENSE.txt",
    *Dir["lib/**/*"].to_a
  ]
  s.homepage = %q{https://github.com/jruby/activerecord-jdbc-adapter}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{jruby-extras}
  s.summary = %q{Derby/JavaDB JDBC driver for Java and Derby/ActiveRecord-JDBC.}
end

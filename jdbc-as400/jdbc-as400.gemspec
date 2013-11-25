# -*- encoding: utf-8 -*-

$LOAD_PATH << File.expand_path('../lib', __FILE__)
require 'jdbc/as400/version'
version = Jdbc::AS400::VERSION
Gem::Specification.new do |s|
  s.name = %q{jdbc-as400}
  s.version = version

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Nick Sieger, Ola Bini and JRuby contributors"]

  s.email = %q{nick@nicksieger.com, ola.bini@gmail.com}
  s.files = [
    "Rakefile", "README.md", "LICENSE.txt",
    *Dir["lib/**/*"].to_a
  ]
  s.homepage = %q{https://github.com/jruby/activerecord-jdbc-adapter}
  s.rdoc_options = ["--main", "README.md"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{jruby-extras}

  s.summary = %q{AS/400 JDBC driver for JRuby and AS/400/ActiveRecord-JDBC (activerecord-jdbcas400-adapter).}
  s.description = %q{Install this gem `require 'jdbc/as400'` and invoke `Jdbc::AS400.load_driver` within JRuby to load the driver.}
end

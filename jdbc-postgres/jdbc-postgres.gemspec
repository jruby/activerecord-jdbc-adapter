# -*- encoding: utf-8 -*-

$LOAD_PATH << File.expand_path('../lib', __FILE__)
require 'jdbc/postgres'
version = Jdbc::Postgres::VERSION
Gem::Specification.new do |s|
  s.name = %q{jdbc-postgres}
  s.version = version

  s.authors = ["Nick Sieger, Ola Bini and JRuby contributors"]
  s.date = %q{2010-12-15}
  s.description = %q{Install this gem and require 'postgres' within JRuby to load the driver.}
  s.email = %q{nick@nicksieger.com, ola.bini@gmail.com}

  s.files = [
    "History.txt", "LICENSE.txt", "README.txt", "Rakefile",
    *Dir["lib/**/*"].to_a
  ]

  s.homepage = %q{https://github.com/jruby/activerecord-jdbc-adapter}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{jruby-extras}
  s.summary = %q{PostgreSQL JDBC driver for Java and PostgreSQL/ActiveRecord-JDBC.}
end

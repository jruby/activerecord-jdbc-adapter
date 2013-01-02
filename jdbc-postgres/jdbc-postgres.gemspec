# -*- encoding: utf-8 -*-

$LOAD_PATH << File.expand_path('../lib', __FILE__)
require 'jdbc/postgres'
version = Jdbc::Postgres::VERSION
Gem::Specification.new do |s|
  s.name = %q{jdbc-postgres}
  s.version = version

  s.authors = ["Nick Sieger, Ola Bini and JRuby contributors"]
  s.email = %q{nick@nicksieger.com, ola.bini@gmail.com}

  s.files = [
    "History.txt", "LICENSE.txt", "README.txt", "Rakefile",
    *Dir["lib/**/*"].to_a
  ]

  s.homepage = %q{https://github.com/jruby/activerecord-jdbc-adapter}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{jruby-extras}

  s.summary = %q{PostgreSQL JDBC driver for JRuby and PostgreSQL/ActiveRecord-JDBC (activerecord-jdbcpostgresql-adapter).}
  s.description = %q{Install this gem `require 'jdbc/postgres'` and invoke `Jdbc::Postgres.load_driver` within JRuby to load the driver.}
end

# -*- encoding: utf-8 -*-

$LOAD_PATH << File.expand_path('../lib', __FILE__)
require 'jdbc/sqlite3'
version = Jdbc::Sqlite3::VERSION
Gem::Specification.new do |s|
  s.name = %q{jdbc-sqlite3}
  s.version = version

  s.authors = ["Nick Sieger, Ola Bini and JRuby contributors"]
  s.date = %q{2011-06-16}
  s.description = %q{Install this gem and require 'sqlite3' within JRuby to load the driver.}
  s.email = %q{nick@nicksieger.com, ola.bini@gmail.com}

  s.files = [
    "Rakefile", "README.txt", "LICENSE.txt",
    *Dir["lib/**/*"].to_a
  ]

  s.homepage = %q{http://jruby-extras.rubyforge.org/ActiveRecord-JDBC}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{jruby-extras}
  s.summary = %q{SQLite3 JDBC driver for Java and SQLite3/ActiveRecord-JDBC.}
end

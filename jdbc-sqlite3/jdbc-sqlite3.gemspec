# -*- encoding: utf-8 -*-
$LOAD_PATH << File.expand_path('../lib', __FILE__)
require 'jdbc/sqlite3/version'

Gem::Specification.new do |gem|
  gem.name = %q{jdbc-sqlite3}
  gem.version = Jdbc::SQLite3::VERSION

  gem.authors = ['Nick Sieger, Ola Bini, Karol Bucek and JRuby contributors']
  gem.email = ['nick@nicksieger.com', 'ola.bini@gmail.com', 'self@kares.org']
  gem.homepage = 'http://github.com/jruby/activerecord-jdbc-adapter/tree/master/jdbc-sqlite3'
  gem.licenses = ['Apache-2']

  Dir.chdir(File.dirname(__FILE__)) { gem.files = `git ls-files`.split("\n") }

  gem.rdoc_options = ["--main", "README.md"]
  gem.require_paths = ["lib"]

  gem.summary = %q{SQLite3 for JRuby, includes SQLite native libraries as well as the JDBC driver.}
  gem.description = %q{Install this gem `require 'jdbc/sqlite3'` and invoke `Jdbc::SQLite3.load_driver` within JRuby to load the driver.}
end

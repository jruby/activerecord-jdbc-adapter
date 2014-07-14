# -*- encoding: utf-8 -*-
$LOAD_PATH << File.expand_path('../lib', __FILE__)
require 'jdbc/postgres/version'

Gem::Specification.new do |gem|
  gem.name = %q{jdbc-postgres}
  gem.version = Jdbc::Postgres::VERSION

  gem.authors = ['Nick Sieger, Ola Bini, Karol Bucek and JRuby contributors']
  gem.email = ['nick@nicksieger.com', 'ola.bini@gmail.com', 'self@kares.org']
  gem.homepage = 'http://github.com/jruby/activerecord-jdbc-adapter/tree/master/jdbc-postgres'
  gem.licenses = ['BSD']

  gem.files = [ 'README.md', 'LICENSE.txt', *Dir['lib/**/*'].to_a ]

  gem.rdoc_options = ["--main", "README.md"]
  gem.require_paths = ["lib"]

  gem.summary = %q{JDBC driver for JRuby and PostgreSQL (used by ActiveRecord-JDBC).}
  gem.description = %q{Install this gem `require 'jdbc/postgres'` and invoke `Jdbc::Postgres.load_driver` within JRuby to load the driver.}
end

# -*- encoding: utf-8 -*-
$LOAD_PATH << File.expand_path('../lib', __FILE__)
require 'jdbc/mariadb/version'

Gem::Specification.new do |gem|
  gem.name = %q{jdbc-mariadb}
  gem.version = Jdbc::MariaDB::VERSION

  gem.authors = ['Nick Sieger, Ola Bini, Karol Bucek and JRuby contributors']
  gem.email = ['nick@nicksieger.com', 'ola.bini@gmail.com', 'self@kares.org']
  gem.homepage = 'http://github.com/jruby/activerecord-jdbc-adapter/tree/master/jdbc-mariadb'
  gem.licenses = ['LGPL']

  Dir.chdir(File.dirname(__FILE__)) { gem.files = `git ls-files`.split("\n") }

  gem.rdoc_options = ["--main", "README.md"]
  gem.require_paths = ["lib"]

  gem.summary = %q{JDBC driver for JRuby and MariaDB/MySQL (usable with ActiveRecord-JDBC).}
  gem.description = %q{Install this gem `require 'jdbc/mariadb'` and invoke `Jdbc::MariaDB.load_driver` within JRuby to load the driver.}
end

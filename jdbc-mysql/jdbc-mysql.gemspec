# -*- encoding: utf-8 -*-
$LOAD_PATH << File.expand_path('../lib', __FILE__)
require 'jdbc/mysql/version'

Gem::Specification.new do |gem|
  gem.name = %q{jdbc-mysql}
  gem.version = Jdbc::MySQL::VERSION

  gem.authors = ['Nick Sieger, Ola Bini, Karol Bucek and JRuby contributors']
  gem.email = ['nick@nicksieger.com', 'ola.bini@gmail.com', 'self@kares.org']
  gem.homepage = 'http://github.com/jruby/activerecord-jdbc-adapter/tree/master/jdbc-mysql'
  gem.licenses = ['GPL-2']

  Dir.chdir(File.dirname(__FILE__)) { gem.files = `git ls-files`.split("\n") }

  gem.rdoc_options = ["--main", "README.md"]
  gem.require_paths = ["lib"]

  gem.summary = %q{JDBC driver for JRuby and MySQL (used by ActiveRecord-JDBC).}
  gem.description = %q{Install this gem `require 'jdbc/mysql'` and invoke `Jdbc::MySQL.load_driver` within JRuby to load the driver.}
end

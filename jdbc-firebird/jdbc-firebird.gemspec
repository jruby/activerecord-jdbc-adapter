# -*- encoding: utf-8 -*-
$LOAD_PATH << File.expand_path('../lib', __FILE__)
require 'jdbc/firebird/version'

Gem::Specification.new do |gem|
  gem.name = %q{jdbc-firebird}
  gem.version = Jdbc::Firebird::VERSION

  gem.authors = ["Karol Bucek"]
  gem.email = %q{self@kares.org}

  gem.authors = ['Nick Sieger, Ola Bini, Karol Bucek and JRuby contributors']
  gem.email = ['nick@nicksieger.com', 'ola.bini@gmail.com', 'self@kares.org']
  gem.homepage = 'http://github.com/jruby/activerecord-jdbc-adapter/tree/master/jdbc-firebird'
  gem.licenses = ['LGPL']

  Dir.chdir(File.dirname(__FILE__)) { gem.files = `git ls-files`.split("\n") }
  
  gem.rdoc_options = ["--main", "README.md"]
  gem.require_paths = ["lib"]

  gem.summary = %q{FireBird JDBC driver (a.k.a. JayBird) for JRuby and FireBird/ActiveRecord-JDBC.}
  gem.description = %q{Install this gem `require 'jdbc/firebird'` and invoke `Jdbc::FireBird.load_driver` within JRuby to load the driver.}
end

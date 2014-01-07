# -*- encoding: utf-8 -*-
$LOAD_PATH << File.expand_path('../lib', __FILE__)
require 'jdbc/jtds/version'

Gem::Specification.new do |gem|
  gem.name = %q{jdbc-jtds}
  gem.version = Jdbc::JTDS::VERSION

  gem.authors = ['Nick Sieger, Ola Bini, Karol Bucek and JRuby contributors']
  gem.email = ['nick@nicksieger.com', 'ola.bini@gmail.com', 'self@kares.org']
  gem.homepage = 'https://github.com/jruby/activerecord-jdbc-adapter'
  gem.licenses = ['LGPL']

  gem.files = [ 'README.md', 'LICENSE.txt', *Dir['lib/**/*'].to_a ]

  gem.rdoc_options = ["--main", "README.md"]
  gem.require_paths = ["lib"]

  gem.summary = %q{jTDS JDBC driver for JRuby and JTDS/ActiveRecord-JDBC (activerecord-jdbcmssql-adapter).}
  gem.description = %q{Install this gem `require 'jdbc/jtds'` and invoke `Jdbc::JDTS.load_driver` within JRuby to load the driver.}
end

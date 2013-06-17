# -*- encoding: utf-8 -*-
$LOAD_PATH << File.expand_path('../lib', __FILE__)

require 'jdbc/mysql/version'

Gem::Specification.new do |s|
  s.name = %q{jdbc-mysql}
  s.version = Jdbc::MySQL::VERSION

  s.authors = ["Nick Sieger, Ola Bini and JRuby contributors"]
  s.email = %q{nick@nicksieger.com, ola.bini@gmail.com}

  s.files = [ "README.md", "LICENSE.txt", *Dir["lib/**/*"].to_a ]
  s.homepage = %q{https://github.com/jruby/activerecord-jdbc-adapter}
  s.rdoc_options = ["--main", "README.md"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{jruby-extras}

  s.summary = %q{MySQL JDBC driver for JRuby and MySQL/ActiveRecord-JDBC (activerecord-jdbcmysql-adapter).}
  s.description = %q{Install this gem `require 'jdbc/mysql'` and invoke `Jdbc::MySQL.load_driver` within JRuby to load the driver.}
end

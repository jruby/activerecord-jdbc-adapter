# -*- encoding: utf-8 -*-

$LOAD_PATH << File.expand_path('../lib', __FILE__)
require 'jdbc/jtds/version'
version = Jdbc::JTDS::VERSION
Gem::Specification.new do |s|
  s.name = %q{jdbc-jtds}
  s.version = version

  s.authors = ["Nick Sieger, Ola Bini and JRuby contributors"]
  s.email = %q{nick@nicksieger.com, ola.bini@gmail.com}

  s.files = [
    "Rakefile", "README.md", "LICENSE.txt",
    *Dir["lib/**/*"].to_a
  ]

  s.homepage = %q{https://github.com/jruby/activerecord-jdbc-adapter}
  s.rdoc_options = ["--main", "README.md"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{jruby-extras}

  s.summary = %q{jTDS JDBC driver for JRuby and JTDS/ActiveRecord-JDBC (activerecord-jdbcmssql-adapter).}
  s.description = %q{Install this gem `require 'jdbc/jtds'` and invoke `Jdbc::JDTS.load_driver` within JRuby to load the driver.}
end

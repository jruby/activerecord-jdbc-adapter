# -*- encoding: utf-8 -*-

$LOAD_PATH << File.expand_path('../lib', __FILE__)
require 'jdbc/hsqldb'
version = Jdbc::HSQLDB::VERSION
Gem::Specification.new do |s|
  s.name = %q{jdbc-hsqldb}
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

  s.summary = %q{HSQLDB JDBC driver for JRuby and HSQLDB/ActiveRecord-JDBC (activerecord-jdbchsqldb-adapter).}
  s.description = %q{Install this gem `require 'jdbc/hsqldb'` and invoke `Jdbc::HSQLDB.load_driver` within JRuby to load the driver.}
end

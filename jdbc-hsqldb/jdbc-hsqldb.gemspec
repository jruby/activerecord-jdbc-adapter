# -*- encoding: utf-8 -*-

$LOAD_PATH << File.expand_path('../lib', __FILE__)
require 'jdbc/hsqldb'
version = Jdbc::HSQLDB::VERSION
Gem::Specification.new do |s|
  s.name = %q{jdbc-hsqldb}
  s.version = version

  s.authors = ["Nick Sieger, Ola Bini and JRuby contributors"]
  s.date = %q{2010-09-15}
  s.description = %q{Install this gem and require 'hsqldb' within JRuby to load the driver.}
  s.email = %q{nick@nicksieger.com, ola.bini@gmail.com}

  s.files = [
    "Rakefile", "README.txt", "LICENSE.txt",
    *Dir["lib/**/*"].to_a
  ]
  s.homepage = %q{http://jruby-extras.rubyforge.org/ActiveRecord-JDBC}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{jruby-extras}
  s.summary = %q{HSQLDB JDBC driver for Java and HSQLDB/ActiveRecord-JDBC.}
end

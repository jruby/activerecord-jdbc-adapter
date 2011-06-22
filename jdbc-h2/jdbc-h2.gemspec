# -*- encoding: utf-8 -*-

$LOAD_PATH << File.expand_path('../lib', __FILE__)
require 'jdbc/h2'
version = Jdbc::H2::VERSION
Gem::Specification.new do |s|
  s.name = %q{jdbc-h2}
  s.version = version

  s.authors = ["Nick Sieger, Ola Bini and JRuby contributors"]
  s.date = %q{2011-06-19}
  s.description = %q{Install this gem and require 'h2' within JRuby to load the driver.}
  s.email = %q{nick@nicksieger.com, ola.bini@gmail.com}
  s.files = [
    "Rakefile", "README.txt", "LICENSE.txt",
    *Dir["lib/**/*"].to_a  
  ]
  s.homepage = %q{http://jruby-extras.rubyforge.org/ActiveRecord-JDBC}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{jruby-extras}
  s.summary = %q{H2 JDBC driver for Java and H2/ActiveRecord-JDBC.}
end

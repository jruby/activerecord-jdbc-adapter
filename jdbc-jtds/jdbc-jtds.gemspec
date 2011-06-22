# -*- encoding: utf-8 -*-

$LOAD_PATH << File.expand_path('../lib', __FILE__)
require 'jdbc/jtds'
version = Jdbc::JTDS::VERSION
Gem::Specification.new do |s|
  s.name = %q{jdbc-jtds}
  s.version = version
  s.authors = ["Nick Sieger, Ola Bini and JRuby contributors"]
  s.date = %q{2010-04-21}
  s.description = %q{Install this gem and require 'jtds' within JRuby to load the driver.}
  s.email = %q{nick@nicksieger.com, ola.bini@gmail.com}

  s.files = [
    "Rakefile", "README.txt", "LICENSE.txt",
    *Dir["lib/**/*"].to_a
  ]

  s.homepage = %q{http://jruby-extras.rubyforge.org/ActiveRecord-JDBC}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{jruby-extras}
end

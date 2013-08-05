# -*- encoding: utf-8 -*-
$LOAD_PATH << File.expand_path('../lib', __FILE__)

require 'jdbc/firebird/version'

Gem::Specification.new do |s|
  s.name = %q{jdbc-firebird}
  s.version = Jdbc::Firebird::VERSION

  s.authors = ["Karol Bucek"]
  s.email = %q{self@kares.org}

  s.files = [ "README.md", "LICENSE.txt", *Dir["lib/**/*"].to_a ]
  s.homepage = %q{https://github.com/jruby/activerecord-jdbc-adapter}
  s.rdoc_options = ["--main", "README.md"]
  s.require_paths = ["lib"]

  s.summary = %q{FireBird JDBC driver (a.k.a. JayBird) for JRuby and FireBird/ActiveRecord-JDBC.}
  s.description = %q{Install this gem `require 'jdbc/firebird'` and invoke `Jdbc::FireBird.load_driver` within JRuby to load the driver.}
end

# -*- encoding: utf-8 -*-
$LOAD_PATH << File.expand_path('../lib', __FILE__)
require 'jdbc/derby/version'

Gem::Specification.new do |gem|
  gem.name = %q{jdbc-derby}
  gem.version = Jdbc::Derby::VERSION

  gem.required_rubygems_version = Gem::Requirement.new(">= 0") if gem.respond_to? :required_rubygems_version=

  gem.authors = ['Nick Sieger, Ola Bini, Karol Bucek and JRuby contributors']
  gem.email = ['nick@nicksieger.com', 'ola.bini@gmail.com', 'self@kares.org']
  gem.homepage = 'http://github.com/jruby/activerecord-jdbc-adapter/tree/master/jdbc-derby'
  gem.licenses = ['Apache-2.0']

  gem.files = [ 'README.md', 'LICENSE.txt', *Dir['lib/**/*'].to_a ]

  gem.rdoc_options = ["--main", "README.md"]
  gem.require_paths = ["lib"]

  gem.summary = %q{Derby/JavaDB for JRuby, includes the JDBC driver as well as the embedded Derby database.}
  gem.description = %q{Install this gem `require 'jdbc/derby'` and invoke `Jdbc::Derby.load_driver` within JRuby to load the driver.}
end

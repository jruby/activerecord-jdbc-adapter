# -*- encoding: utf-8 -*-
arjdbc_lib = File.expand_path("../../lib", __FILE__)
$:.push arjdbc_lib unless $:.include?(arjdbc_lib)
require 'arjdbc/version'

Gem::Specification.new do |s|
  s.name        = "activerecord-jdbcpostgresql-adapter"
  s.version     = version = ArJdbc::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors = ["Nick Sieger, Ola Bini and JRuby contributors"]
  s.description = %q{Install this gem to use Postgres with JRuby on Rails.}
  s.email = %q{nick@nicksieger.com, ola.bini@gmail.com}

  s.homepage = %q{https://github.com/jruby/activerecord-jdbc-adapter}
  s.rubyforge_project = %q{jruby-extras}
  s.summary = %q{Postgres JDBC adapter for JRuby on Rails.}

  s.require_paths = ["lib"]
  s.files = `git ls-files`.split("\n") # assuming . working directory

  s.add_dependency 'activerecord-jdbc-adapter', "~>#{version}"
  s.add_dependency 'jdbc-postgres', '>= 9.1' #, '< 9.3'
end


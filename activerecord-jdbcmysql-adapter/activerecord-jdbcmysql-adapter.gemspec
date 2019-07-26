# -*- encoding: utf-8 -*-
arjdbc_lib = File.expand_path("../../lib", __FILE__)
$:.push arjdbc_lib unless $:.include?(arjdbc_lib)
require 'arjdbc/version'

Gem::Specification.new do |gem|
  gem.name        = "activerecord-jdbcmysql-adapter"
  gem.version     = version = ArJdbc::VERSION
  gem.platform    = 'java' # since base gem is tagged

  gem.authors = ['Nick Sieger, Ola Bini, Karol Bucek and JRuby contributors']
  gem.email = ['nick@nicksieger.com', 'ola.bini@gmail.com', 'self@kares.org']
  gem.homepage = 'https://github.com/jruby/activerecord-jdbc-adapter'
  gem.license = "BSD"

  gem.rubyforge_project = %q{jruby-extras}
  gem.summary = %q{MySQL JDBC adapter for JRuby on Rails.}

  gem.require_paths = ["lib"]
  gem.files = `git ls-files`.split("\n") # assuming . working directory

  gem.add_dependency 'activerecord-jdbc-adapter', "#{version}"
  gem.add_dependency 'jdbc-mysql', '~> 5.1.36', '< 9'
end

# -*- encoding: utf-8 -*-
arjdbc_lib = File.expand_path("../../lib", __FILE__)
$:.push arjdbc_lib unless $:.include?(arjdbc_lib)
require 'arjdbc/version'

Gem::Specification.new do |gem|
  gem.name        = "activerecord-jdbch2-adapter"
  gem.version     = version = ArJdbc::VERSION
  gem.platform    = Gem::Platform::RUBY

  gem.authors = ['Nick Sieger, Ola Bini, Karol Bucek and JRuby contributors']
  gem.email = ['nick@nicksieger.com', 'ola.bini@gmail.com', 'self@kares.org']
  gem.homepage = 'https://github.com/jruby/activerecord-jdbc-adapter'
  gem.license = "BSD"

  gem.homepage = %q{https://github.com/jruby/activerecord-jdbc-adapter}
  gem.rubyforge_project = %q{jruby-extras}
  gem.summary = %q{H2 JDBC adapter for JRuby on Rails.}

  gem.require_paths = ["lib"]
  gem.files = `git ls-files`.split("\n") # assuming . working directory

  gem.add_dependency 'activerecord-jdbc-adapter', "~>#{version}"
  gem.add_dependency 'jdbc-h2', '~> 1.4.0'

end

# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{activerecord-jdbcmssql-adapter}
  s.version = "1.0.0"
  s.platform = Gem::Platform.new([nil, "java", nil])

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Nick Sieger, Ola Bini and JRuby contributors"]
  s.date = %q{2010-10-14}
  s.description = %q{Install this gem to use MS-SQL with JRuby on Rails.}
  s.email = %q{nick@nicksieger.com, ola.bini@gmail.com}
  s.extra_rdoc_files = ["Manifest.txt", "README.txt", "LICENSE.txt"]
  s.files = ["Manifest.txt", "Rakefile", "README.txt", "LICENSE.txt", "lib/active_record/connection_adapters/jdbcmssql_adapter.rb"]
  s.homepage = %q{http://jruby-extras.rubyforge.org/ActiveRecord-JDBC}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{jruby-extras}
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{MS-SQL JDBC adapter for JRuby on Rails.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activerecord-jdbc-adapter>, ["= 1.0.0"])
      s.add_runtime_dependency(%q<jdbc-jtds>, [">= 1.2.5"])
      s.add_development_dependency(%q<rubyforge>, [">= 2.0.4"])
      s.add_development_dependency(%q<hoe>, [">= 2.6.1"])
    else
      s.add_dependency(%q<activerecord-jdbc-adapter>, ["= 1.0.0"])
      s.add_dependency(%q<jdbc-jtds>, [">= 1.2.5"])
      s.add_dependency(%q<rubyforge>, [">= 2.0.4"])
      s.add_dependency(%q<hoe>, [">= 2.6.1"])
    end
  else
    s.add_dependency(%q<activerecord-jdbc-adapter>, ["= 1.0.0"])
    s.add_dependency(%q<jdbc-jtds>, [">= 1.2.5"])
    s.add_dependency(%q<rubyforge>, [">= 2.0.4"])
    s.add_dependency(%q<hoe>, [">= 2.6.1"])
  end
end

# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{activerecord-jdbchsqldb-adapter}
  s.version = "0.9.3"
  s.platform = Gem::Platform.new([nil, "java", nil])

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Nick Sieger, Ola Bini and JRuby contributors"]
  s.date = %q{2010-02-23}
  s.description = %q{Install this gem to use HSQLDB with JRuby on Rails.}
  s.email = %q{nick@nicksieger.com, ola.bini@gmail.com}
  s.extra_rdoc_files = ["Manifest.txt", "README.txt", "LICENSE.txt"]
  s.files = ["Manifest.txt", "Rakefile", "README.txt", "LICENSE.txt", "lib/active_record/connection_adapters/jdbchsqldb_adapter.rb"]
  s.homepage = %q{http://jruby-extras.rubyforge.org/ActiveRecord-JDBC}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{jruby-extras}
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{HSQLDB JDBC adapter for JRuby on Rails.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activerecord-jdbc-adapter>, ["= 0.9.3"])
      s.add_runtime_dependency(%q<jdbc-hsqldb>, [">= 1.8.0.7"])
    else
      s.add_dependency(%q<activerecord-jdbc-adapter>, ["= 0.9.3"])
      s.add_dependency(%q<jdbc-hsqldb>, [">= 1.8.0.7"])
    end
  else
    s.add_dependency(%q<activerecord-jdbc-adapter>, ["= 0.9.3"])
    s.add_dependency(%q<jdbc-hsqldb>, [">= 1.8.0.7"])
  end
end

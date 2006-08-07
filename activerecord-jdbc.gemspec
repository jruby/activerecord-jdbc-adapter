require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = "ActiveRecord-JDBC"
  s.version = "0.0.1"
  s.author = "JRuby-extras"
  s.email = "ola@ologix.com"
  s.homepage = "http://jruby-extras.rubyforge.org/"
  s.platform = Gem::Platform::RUBY #should be JAVA
  s.summary = "JDBC support for ActiveRecord. Only usable within JRuby"
  candidates = Dir.glob("{lib,test}/**/*") + ["LICENSE","init.rb","install.rb"]
  s.files = candidates.delete_if do |item| item.include?(".svn") || item.include?("rdoc") end
  s.require_path = "lib"
  s.autorequire = "active_record/connection_adapters/jdbc_adapter"
  s.has_rdoc = true
end

if $0 == __FILE__
  Gem::manage_gems
  Gem::Builder.new(spec).build
end

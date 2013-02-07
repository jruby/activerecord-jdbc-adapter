appraise "rails23" do
  gem "activerecord", "~> 2.3.16"
  gem "rails", "~> 2.3.16"
end

appraise "rails30" do
  gem "activerecord", "~> 3.0.20"
end

appraise "rails31" do
  gem "activerecord", "~> 3.1.10"
end

appraise "rails32" do
  gem "activerecord", "~> 3.2.11"
end

# NOTE: make sure you're using --1.9 with 4.0 (alternatively use jruby-head) !
appraise "rails40" do
  #gem "activerecord", "~> 4.0.0"
  # until there's a 4.0 release :
  gem 'rails', :github => 'rails/rails'
  gem 'journey', :github => 'rails/journey'
  gem 'activerecord-deprecated_finders', :github => 'rails/activerecord-deprecated_finders', :require => nil
end

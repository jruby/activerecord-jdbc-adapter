appraise "rails23" do
  gem "activerecord", "~> 2.3.18", :require => false
  gem "rails", "~> 2.3.18"
end

appraise "rails30" do
  gem "activerecord", "~> 3.0.20", :require => false
end

appraise "rails31" do
  gem "activerecord", "~> 3.1.12", :require => false
end

appraise "rails32" do
  gem 'i18n', '< 0.7'
  gem "activerecord", "~> 3.2.19", :require => false
end

appraise "rails40" do
  gem "activerecord", "~> 4.0.12", :require => false
end

appraise "rails41" do
  gem "activerecord", "~> 4.1.8", :require => false
end

appraise "rails42" do
  gem "activerecord", "~> 4.2.0", :require => false
end

appraise "railsNG" do
  branch = ( ENV['rails_branch'] || 'master' )
  gem "activerecord", :github => 'rails/rails', :branch => branch, :require => false
  gem 'rails', :github => 'rails/rails', :branch => branch
  gem 'arel', :github => 'rails/arel', :branch => 'master'
end

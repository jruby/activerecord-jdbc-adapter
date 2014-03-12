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
  gem "activerecord", "~> 3.2.17", :require => false
end

appraise "rails40" do
  # NOTE: make sure you're using --1.9 with AR-4.0
  gem "activerecord", "~> 4.0.3", :require => false
end

appraise "rails41" do
  # NOTE: make sure you're using --1.9 with AR-4.1
  if branch = ENV['rails_branch']
    gem "activerecord", :github => 'rails/rails', :branch => branch, :require => false
    gem 'rails', :github => 'rails/rails', :branch => branch
  else
    gem "activerecord", '4.1.0.rc1', :require => false
  end
end
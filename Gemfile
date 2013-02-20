source "http://rubygems.org"

#############
# WARNING: Separate from the Gemspec. Please update both files
#############

gem "json_pure", "~> 1.6"
gem "multi_json", "~> 1.3"
gem "rake"

gem "interact", :git => "git://github.com/vito/interact.git"
gem "cfoundry", :git => "git://github.com/cloudfoundry/vmc-lib.git"
gem "clouseau", :git => "git://github.com/vito/clouseau.git"
gem "mothership", :git => "git://github.com/vito/mothership.git"

git "git://github.com/cloudfoundry/vmc-plugins.git" do
  gem "admin-vmc-plugin"
  gem "console-vmc-plugin"
  gem "mcf-vmc-plugin"
  gem "manifests-vmc-plugin"
  gem "tunnel-vmc-plugin"
end

group :test do
  gem "rspec", "~> 2.11"
  gem "webmock", "~> 1.9"
  gem "rr", "~> 1.0"
end

group :development do
  gem "pry"
  gem "gem-release"
end

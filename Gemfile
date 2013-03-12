source "http://rubygems.org"

gemspec

gem "interact", :git => "git://github.com/vito/interact.git"
gem "cfoundry", :path => "../vmc-lib" #:git => "git://github.com/cloudfoundry/vmc-lib.git", :submodules => true
gem "clouseau", :git => "git://github.com/vito/clouseau.git"
gem "mothership", :git => "git://github.com/vito/mothership.git"

gem "admin-vmc-plugin", :git => "git://github.com/cloudfoundry/admin-vmc-plugin.git"
gem "console-vmc-plugin", :git => "git://github.com/cloudfoundry/console-vmc-plugin.git"
gem "mcf-vmc-plugin", :git => "git://github.com/cloudfoundry/mcf-vmc-plugin.git"
gem "manifests-vmc-plugin", :git => "git://github.com/cloudfoundry/manifests-vmc-plugin.git"
gem "tunnel-vmc-plugin", :git => "git://github.com/cloudfoundry/tunnel-vmc-plugin.git"

group :test do
  gem "rspec", "~> 2.11"
  gem "webmock", "~> 1.9"
  gem "rr", "~> 1.0"
  gem "ffaker"
  gem "fakefs"
  gem "parallel_tests"
end

group :development do
  gem "gem-release"
end

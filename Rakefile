require "rake"

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "vmc/version"

task :default => :spec

desc "Run specs"
task :spec => "bundler:install" do
  sh("rspec")
end

namespace :bundler do
  desc "Install bundler and gems"
  task "install" do
    sh("(gem list --local bundler | grep bundler || gem install bundler) && (bundle check || bundle install)")
  end
end

namespace :gem do
  desc "Build Gem"
  task :build do
    sh "gem build vmc.gemspec"
  end

  desc "Install Gem"
  task :install => :build do
    sh "gem install --local vmc-#{VMC::VERSION}"
    sh "rm vmc-#{VMC::VERSION}.gem"
  end

  desc "Uninstall Gem"
  task :uninstall do
    sh "gem uninstall vmc"
  end

  desc "Reinstall Gem"
  task :reinstall => [:uninstall, :install]
end

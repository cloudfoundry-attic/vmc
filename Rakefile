require "rake"
require "rspec/core/rake_task"

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "vmc/version"

RSpec::Core::RakeTask.new(:spec)
task :default => :spec

namespace :deploy do
  def last_staging_sha
    `git rev-parse latest-staging`.strip
  end

  def last_release_sha
    `git rev-parse latest-release`.strip
  end

  def last_staging_ref_was_released?
    last_staging_sha == last_release_sha
  end

  task :staging, :version do |_, args|
    sh "gem bump --push #{"--version #{args.version}" if args.version}" if last_staging_ref_was_released?
    sh "git tag -f latest-staging"
    sh "git push origin :latest-staging"
    sh "git push origin latest-staging"
  end

  task :gem do
    sh "git fetch"
    sh "git checkout #{last_staging_sha}"
    sh "gem release --tag"
    sh "git tag -f latest-release"
    sh "git push origin :latest-release"
    sh "git push origin latest-release"
  end
end

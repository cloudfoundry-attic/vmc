require "rake"
require "auto_tagger"
require "rspec/core/rake_task"

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "vmc/version"

RSpec::Core::RakeTask.new(:spec)
task :default => :spec

namespace :deploy do
  def auto_tag
    @auto_tag ||= AutoTagger::Base.new(
      :stage => "staging",
      :stages => %w[staging],
      :verbose => true,
      :push_refs => false,
      :refs_to_keep => 100
    )
  end

  def last_staging_ref
    auto_tag.refs_for_stage("staging").last
  end

  def checkout_last_staging_ref
    sh "git fetch"
    sh "git checkout #{last_staging_ref}"
  end

  def last_staging_ref_was_released?
    last_staging_ref.sha == `git rev-parse latest-release`.strip
  end

  task :staging, :version do |_, args|
    sh "gem bump --push #{"--version #{args.version}" if args.version}" if last_staging_ref_was_released?
    sh "git push origin #{auto_tag.create_ref.name}"
    auto_tag.delete_locally
    auto_tag.delete_on_remote
  end

  task :test do
    checkout_last_staging_ref
    sh "rm -f *.gem"
    sh "gem build vmc.gemspec"
  end

  task :gem do
    checkout_last_staging_ref
    sh "gem release --tag"
    sh "git tag -f latest-release"
    sh "git push origin latest-release"
  end
end

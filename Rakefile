require "rake"
require "rspec/core/rake_task"

specfile, _ = Dir["*.gemspec"]
SPEC = Gem::Specification.load(specfile)
CURRENT_VERSION = SPEC.version.to_s.freeze

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

  def next_minor
    Gem::Version.new(CURRENT_VERSION + ".0").bump.to_s
  end

  def next_rc
    unless CURRENT_VERSION =~ /rc/
      "#{next_minor}.rc1"
    end
  end

  task :staging, :version do |_, args|
    version = args.version || next_rc
    sh "gem bump --push #{"--version #{version}" if version}" if last_staging_ref_was_released?
    sh "git tag -f latest-staging"
    sh "git push origin :latest-staging"
    sh "git push origin latest-staging"
  end

  task :candidate do
    sh "git fetch"
    sh "git checkout latest-staging"
    sh "gem release"
    sh "git tag -f v#{CURRENT_VERSION}"
    sh "git tag -f latest-release"
    sh "git push origin :latest-release"
    sh "git push origin latest-release"
  end

  task :release do
    version = CURRENT_VERSION.sub(/\.rc\d+/, "")

    prereleases = SPEC.runtime_dependencies.select(&:prerelease?)
    unless prereleases.empty?
      puts "The following dependencies must be released:"
      prereleases.each do |pre|
        puts "- #{pre.name}"
      end

      puts ""

      raise
    end

    # grab the last release candidate
    sh "git checkout latest-release -b release-v#{version}"

    # update the version
    sh "gem bump --version #{version}"

    # switch to master
    sh "git checkout master"

    # merge the new version number back into master
    sh "git merge release-v#{version}"

    # apply tags
    sh "git tag -f v#{version}"
    sh "git tag -f latest-release"
    sh "git tag -f latest-stable"
    sh "git push origin master"
    sh "git push origin :latest-release 2> /dev/null || exit 0"
    sh "git push origin :latest-stable 2> /dev/null || exit 0"
    sh "git push origin latest-release"
    sh "git push origin latest-stable"
    sh "git push origin v#{version}"

    # check out the release tag
    sh "git checkout latest-stable"

    # build the gem and push the gem to rubygems
    sh "rm -f *.gem"
    sh "gem build *.gemspec"
    sh "gem push *.gem"
    sh "rm -f *.gem"

    puts "You are now on the latest-release tag. You'll have to switch back to your working branch."
  end
end

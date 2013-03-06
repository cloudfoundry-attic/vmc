require "rake"
require "rspec/core/rake_task"

specfile, _ = Dir["*.gemspec"]
SPEC = Gem::Specification.load(specfile)
CURRENT_VERSION = SPEC.version.to_s.freeze

RSpec::Core::RakeTask.new(:spec)
task :default => :spec

# looking for a way to push gems? check out the new frontend-release git repo!
# git@github.com:pivotal-vmware/frontend-release.git

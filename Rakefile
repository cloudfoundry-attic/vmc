require "rake"
require "auto_tagger"
require "rspec/core/rake_task"

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "vmc/version"

RSpec::Core::RakeTask.new(:spec)
task :default => :spec

namespace :release do
  STAGES = %w[ci staging release].freeze
  REFS_TO_KEEP = 100.freeze

  def auto_tag(stage=nil)
    @auto_tag ||= begin
      raise ArgumentError if stage.nil?
      AutoTagger::Base.new(:stages => STAGES, :stage => stage, :verbose => true, :push_refs => false, :refs_to_keep => REFS_TO_KEEP)
    end
  end

  task :stage, :ref do |_, args|
    auto_tag "staging"
    sh "git push origin #{auto_tag.create_ref(args.ref).name}"
    auto_tag.delete_locally
    auto_tag.delete_on_remote
  end

  task :test do
    last_staging_ref = auto_tag("release").last_ref_from_previous_stage
    sh "rm *.gem && git checkout #{last_staging_ref} && gem build"
  end

  task :rubygems do
    last_staging_ref = auto_tag("release").last_ref_from_previous_stage
    sh "git checkout #{last_staging_ref.sha} && gem bump --release --push --tag"
  end
end

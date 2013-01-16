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

  def create_tag_and_push
    last_ref_from_previous_stage = auto_tag.last_ref_from_previous_stage
    tag = auto_tag.create_ref(last_ref_from_previous_stage && last_ref_from_previous_stage.sha)
    sh "git push origin #{tag.name}"
    auto_tag.delete_locally
    auto_tag.delete_on_remote
  end

  def last_sha_for(stage)
    last = auto_tag.refs_for_stage(stage).last
    last && last.sha
  end

  task :ci do
    auto_tag "ci"

    create_tag_and_push
  end

  task :stage, :ref do |_, args|
    auto_tag "staging"

    ref_to_stage = args.ref || last_sha_for("ci")
    sh "git checkout #{ref_to_stage}" if ref_to_stage

    last_sha_for_staging = last_sha_for("staging")
    sh "gem bump --push" if last_sha_for_staging.nil? || (last_sha_for_staging == last_sha_for("release"))
    create_tag_and_push
  end

  task :rubygems do
    auto_tag "release"

    last_stage = auto_tag.last_ref_from_previous_stage
    sh "git checkout #{last_stage.sha} && gem release --tag" if last_stage
  end
end

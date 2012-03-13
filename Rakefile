require 'rake'
require 'spec/rake/spectask'

desc "Run specs"
task :spec => :build do
  Spec::Rake::SpecTask.new('spec') do |t|
    t.spec_opts = %w(-fs -c)
    t.spec_files = FileList['spec/**/*_spec.rb']
  end
end

desc "Synonym for spec"
task :test => :spec
desc "Synonym for spec"
task :tests => :spec
task :default => :spec

def tests_path
  if @tests_path == nil
    @tests_path = File.join(Dir.pwd, "spec/assets/tests")
  end
  @tests_path
end
TESTS_PATH = tests_path

BUILD_ARTIFACT = File.join(Dir.pwd, "spec/assets/.build")

TESTS_TO_BUILD = ["#{TESTS_PATH}/java_web/java_tiny_app",
#             "#{TESTS_PATH}/grails/guestbook",
             "#{TESTS_PATH}/lift/hello_lift",
             "#{TESTS_PATH}/spring/roo-guestbook",
             "#{TESTS_PATH}/spring/spring-osgi-hello",
             "#{TESTS_PATH}/standalone/java_app",
             "#{TESTS_PATH}/standalone/python_app"
            ]

desc "Build the tests. If the git hash associated with the test assets has not changed, nothing is built. To force a build, invoke 'rake build[--force]'"
task :build, [:force] do |t, args|
  sh('bundle install')
  sh('git submodule update --init')
  puts "\nBuilding tests"
  if build_required? args.force
    ENV['MAVEN_OPTS']="-XX:MaxPermSize=256M"
    TESTS_TO_BUILD.each do |test|
      puts "\tBuilding '#{test}'"
      Dir.chdir test do
        sh('mvn package -DskipTests') do |success, exit_code|
          unless success
            clear_build_artifact
            do_mvn_clean('-q')
            fail "\tFailed to build #{test} - aborting build"
          end
        end
      end
      puts "\tCompleted building '#{test}'"
    end
    save_git_hash
  else
    puts "Built artifacts in sync with test assets - no build required"
  end
end

desc "Clean the build artifacts"
task :clean do
  puts "\nCleaning tests"
  clear_build_artifact
  TESTS_TO_BUILD.each do |test|
    puts "\tCleaning '#{test}'"
    Dir.chdir test do
      do_mvn_clean
    end
    puts "\tCompleted cleaning '#{test}'"
  end
end

def build_required? (force_build=nil)
  if File.exists?(BUILD_ARTIFACT) == false or (force_build and force_build == "--force")
    return true
  end
  Dir.chdir(tests_path) do
    saved_git_hash = IO.readlines(BUILD_ARTIFACT)[0].split[0]
    git_hash = `git rev-parse --short=8 --verify HEAD`
    saved_git_hash.to_s.strip != git_hash.to_s.strip
  end
end

def save_git_hash
  Dir.chdir(tests_path) do
    git_hash = `git rev-parse --short=8 --verify HEAD`
    File.open(BUILD_ARTIFACT, 'w') {|f| f.puts("#{git_hash}")}
  end
end

def clear_build_artifact
  puts "\tClearing build artifact #{BUILD_ARTIFACT}"
  File.unlink BUILD_ARTIFACT if File.exists? BUILD_ARTIFACT
end

def do_mvn_clean options=nil
  sh("mvn clean #{options}")
end

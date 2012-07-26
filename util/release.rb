# 1. bump cfoundry
# 2. gerrit-push cfoundry
# 3. release cfoundry
# 4. bump vmc-ng version
# 5. bump cfoundry dep in vmc
# 6. gerrit-push vmc
# 7. update vmc-ng in vmc-glue
# 8. gerrit-push vmc-glue
# 9. release vmc-glue

require "rubygems"
require "pathname"

require "interact"
require "mothership"
require "mothership/pretty"
require "mothership/progress"

if defined? VMC || defined? CFoundry
  $stderr.puts "VMC already defined; don't use bundle exec."
  exit(1)
end


root = File.expand_path("~/Dropbox")

VMC_DIR = "#{root}/vmc"
VMC_VER = "#{VMC_DIR}/lib/vmc/version.rb"

CFOUNDRY_DIR = "#{root}/vmc-lib"
CFOUNDRY_VER = "#{CFOUNDRY_DIR}/lib/cfoundry/version.rb"

GLUE_DIR = "#{root}/vmc-glue"

require CFOUNDRY_VER
require VMC_VER


class DailyBumper < Mothership
  include Interactive
  include Mothership::Pretty
  include Mothership::Progress

  option(:cfoundry, :type => :boolean, :default => true,
         :desc => "Bump CFoundry?")

  option(:vmc, :type => :boolean, :default => true,
         :desc => "Bump VMC?")

  option(:glue, :type => :boolean, :default => true,
         :desc => "Bump glue gem?")

  option(:cfoundry_version, :desc => "New CFoundry version") {
    ask "Bumping CFoundry from #{CFoundry::VERSION}",
      :default => bump_version(CFoundry::VERSION)
  }

  option(:vmc_version, :desc => "New VMC version") {
    ask "Bumping VMC from #{VMC::VERSION}",
      :default => bump_version(VMC::VERSION)
  }

  option(:dry_run, :type => :boolean, :default => false, :alias => "-d",
         :desc => "Dry run")

  option(:push, :type => :boolean, :default => true,
         :desc => "Push to gerrit and Rubygems.")

  def default_action
    begin
      new_cf_ver =
        option(:cfoundry) ?
          option(:cfoundry_version) :
          CFoundry::VERSION

      new_vmc_ver =
        option(:vmc) ?
          option(:vmc_version) :
          VMC::VERSION
    rescue Interrupt
      err "\nOK NEVERMIND THEN, GEEZ."
    end

    if option(:cfoundry)
      save_version(CFOUNDRY_VER, new_cf_ver)
      commit(CFOUNDRY_DIR, new_cf_ver)
      gerrit_push(CFOUNDRY_DIR)
      release(CFOUNDRY_DIR, "cfoundry", new_cf_ver)
    end

    if option(:vmc)
      bump_dep(VMC_DIR, "vmc", "cfoundry", new_cf_ver) if option(:cfoundry)
      save_version(VMC_VER, new_vmc_ver)
      commit(VMC_DIR, new_vmc_ver)
      gerrit_push(VMC_DIR, "ng")
    end

    if option(:glue)
      vmc_head = current_head(VMC_DIR)
      update_submodule(GLUE_DIR, "vmc-ng", new_vmc_ver, vmc_head, "ng")
      commit(GLUE_DIR, new_vmc_ver)
      gerrit_push(GLUE_DIR)
      release(GLUE_DIR, "vmc", new_vmc_ver)
    end
  rescue Interrupt
    puts ""
    rollback!
    puts "\nBye!"
    exit(0)
  rescue Exception
    rollback!
    raise
  end

  private

  def rollback!
    return unless @rollbacks && !@rollbacks.empty?

    @quiet = true

    puts c("Rolling back changes...", :warning)
    @rollbacks.reverse_each do |r|
      r.call
    end
  end

  def rollback(name, &blk)
    @rollbacks ||= []
    @rollbacks << proc {
      with_progress("Undoing #{name}") do |s|
        unless option(:dry_run)
          blk.call(s)
        end
      end
    }
  end

  def current_head(dir)
    ref = File.read("#{dir}/.git/HEAD").chomp.sub(/^ref:\s+/, "")
    File.read("#{dir}/.git/#{ref}").chomp
  end

  def update_submodule(dir, sub, ver, target_head, branch = "master")
    return unless ask "Update #{c(sub, :name)} to #{ver}?", :default => true

    before = nil
    chdir("#{dir}/#{sub}") do
      before = current_head(".")
      until current_head(".") == target_head
        sleep 1
        sh "git pull origin #{branch}"
      end
    end

    rollback(:update_submodule) do
      chdir("#{dir}/#{sub}") do
        system "git reset #{before} > /dev/null"
      end
    end
  end

  def bump_dep(dir, name, dep, ver)
    with_progress(
        "Bumping #{c(dep, :name)} to #{c(ver, :name)} in #{c(name, :name)}") do |s|
      sub_file(
        s,
        "#{dir}/#{name}.gemspec",
        /add_(runtime_)?dependency(\s+)(["'])#{dep}\3,(\s+)(["'])([^0-9]+).+\5/,
        "add_\\1dependency\\2\\3#{dep}\\3,\\4\\5\\6#{ver}\\5")
    end
  end

  def commit(dir, new_version)
    before = nil
    chdir(dir) do
      before = `git reflog -n 1`.split.first

      sh "git add -p"
      sh "git commit -m 'bump to #{new_version}'"
    end

    puts ""

    rollback(:commit) do
      chdir(dir) do
        system "git reset #{before} > /dev/null"
      end
    end
  end

  def gerrit_push(dir, branch = "master")
    return unless option(:push)
    return unless ask "Push to gerrit?", :default => true

    chdir(dir) do
      sh "gerrit-push --branch #{branch}"
    end

    puts ""

    rollback(:gerrit_push) do |s|
      s.fail do
        puts "Cannot rollback gerrit-push; please abandon manually."
      end
    end
  end

  def release(dir, name, version)
    return unless option(:push)

    chdir(dir) do
      sh "gem build #{name}.gemspec"
      sh "gem push #{name}-#{version}.gem"
      sh "rm #{name}-#{version}.gem"
    end

    puts ""

    rollback(:release) do |s|
      s.fail do
        puts "Cannot rollback release; please yank the gem manually."
      end
    end
  end

  def sh(cmd)
    system(cmd) || err("\nCommand failed: #{cmd}")
  end

  def system(cmd)
    puts "\n#{c(cmd, :name)}:" unless @quiet
    if option(:dry_run)
      puts "(dry run; skipped)" unless @quiet
      true
    else
      Kernel.system(cmd)
    end
  end

  def err(msg)
    puts c(msg, :bad)
    exit 1
  end

  def save_version(file, ver)
    with_progress("Bumping version file to #{c(ver, :name)}") do |s|
      sub_file(s, file, /VERSION = .+$/, "VERSION = #{ver.inspect}")
    end
  end

  def chdir(dir)
    puts "cd #{dir}" unless @quiet

    Dir.chdir(dir) do
      yield
    end
  end

  def sub_file(skipper, file, find, replace = nil, &blk)
    relative = Pathname.new(file).relative_path_from(Pathname.pwd)

    old = File.read(file)
    new =
      if replace
        old.sub(find, replace)
      else
        old.sub(find, &blk)
      end

    if old == new
      skipper.fail do
        err "Replacement failed!"
      end
    end

    if option(:dry_run)
      skipper.skip do
        puts d("#{relative}:")
        puts ""
        puts d(new)
        puts ""
      end
    end

    File.open(file, "w") do |io|
      io.print new
    end

    rollback("replace #{find.inspect} in #{relative}") do
      File.open(file, "w") do |io|
        io.print old
      end
    end
  end

  def bump_version(str)
    str.gsub(/([0-9]+)$/) do
      $1.to_i + 1
    end
  end
end

DailyBumper.start(ARGV)

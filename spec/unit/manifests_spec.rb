require 'spec_helper'

describe 'manifests' do
  MY_MANIFEST = spec_asset("manifests/my-manifest.yml")
  SYM_MANIFEST = spec_asset("manifests/sym-manifest.yml")
  SUB_MANIFEST = spec_asset("manifests/sub-manifest.yml")
  BAD_MANIFEST = spec_asset("manifests/bad-manifest.yml")

  it "loads the specified manifest file" do
    app = VMC::Cli::Command::Base.new(:manifest => MY_MANIFEST)
    app.manifest("foo").should == 1
    app.manifest("bar").should == 2
  end

  it "loads the nearest manifest.yml file if none specified" do
    Dir.chdir(spec_asset("manifests/someapp")) do
      app = VMC::Cli::Command::Base.new
      app.manifest_file.should == File.expand_path("manifest.yml")
      app.manifest("fizz").should == 1
      app.manifest("buzz").should == 2
    end
  end

  it "searches upward for the manifest.yml file" do
    Dir.chdir(spec_asset("manifests/someapp/somedir/somesubdir")) do
      app = VMC::Cli::Command::Base.new
      app.manifest_file.should == File.expand_path("../../manifest.yml")
      app.manifest("fizz").should == 1
      app.manifest("buzz").should == 2
    end
  end

  it "has an empty manifest if none found" do
    Dir.chdir(spec_asset("manifests/somenomanifestapp")) do
      app = VMC::Cli::Command::Base.new
      app.manifest_file.should == nil
    end
  end

  describe 'symbol resolution' do
    before(:all) do
      @cli = VMC::Cli::Command::Base.new(:manifest => SYM_MANIFEST)
    end

    it "fails if there is an unknown symbol" do
      proc {
        VMC::Cli::Command::Base.new(:manifest => BAD_MANIFEST)
      }.should raise_error
    end

    it "searches under properties hash" do
      @cli.manifest("a").should == 43
      @cli.manifest("b").should == "baz"
      @cli.manifest("c").should == 42
      @cli.manifest("d").should == "bar"

      @cli.manifest("foo").should == "foo baz baz"
      @cli.manifest("bar").should == "fizz 43"
    end

    it "searches from the toplevel if not found in properties" do
      @cli.manifest("fizz").should == "foo bar baz"
      @cli.manifest("buzz").should == "fizz 42"
    end

    it "resolves lexically" do
      @cli.manifest("some-hash", "hello", "foo").should == 1
      @cli.manifest("some-hash", "hello", "bar").should == "1-2"
      @cli.manifest("some-hash", "goodbye", "fizz").should == 3
      @cli.manifest("some-hash", "goodbye", "buzz").should == 4

      @cli.manifest("parent", "foo").should == 0
      @cli.manifest("parent", "bar").should == "0"
      @cli.manifest("parent", "sub", "foo").should == 1
      @cli.manifest("parent", "sub", "bar").should == "1"
      @cli.manifest("parent", "sub", "baz").should == "-1"
      @cli.manifest("parent", "sub2", "foo").should == 2
      @cli.manifest("parent", "sub2", "bar").should == "2"
      @cli.manifest("parent", "sub2", "baz").should == "-2"
    end

    it "predefines a few helpers" do
      @cli.manifest("base").should == "somecloud.com"
      @cli.manifest("url").should == "api.somecloud.com"
      @cli.manifest("random").should be_a(String)
    end

    it "resolves recursively" do
      @cli.manifest("third").should == "baz"
      @cli.manifest("second").should == "bar baz"
      @cli.manifest("first").should == "foo bar baz"
    end
  end

  describe 'extension manifests' do
    before(:all) do
      @cli = VMC::Cli::Command::Base.new(:manifest => SUB_MANIFEST)
    end

    it "inherits values from a parent manifest" do
      @cli.manifest("a").should == 43
      @cli.manifest("b").should == "baz"
      @cli.manifest("c").should == 42
    end

    it "overrides values set in the parent" do
      @cli.manifest("d").should == "subbed bar"
    end

    it "merges before symbol resolution" do
      @cli.manifest("third").should == "baz"
      @cli.manifest("second").should == "subbed baz"
      @cli.manifest("first").should == "foo subbed baz"
    end

    it "merges depth-first" do
      @cli.manifest("some-hash", "hello", "foo").should == "one"
      @cli.manifest("some-hash", "hello", "bar").should == "one-2"
      @cli.manifest("some-hash", "goodbye", "fizz").should == 3
      @cli.manifest("some-hash", "goodbye", "buzz").should == 4
    end
  end
end

module VMC::TestSupport
end

Dir.glob(File.expand_path("../test_support/*", __FILE__)).each { |file| require file }
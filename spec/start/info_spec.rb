require File.expand_path("../../helpers", __FILE__)

describe "Start#info" do
  it "orders runtimes by category, status, and series" do
    running(:info, :runtimes => true) do
      does("Getting runtimes")
      known_runtimes = %w(java7 java node08 node06 node ruby19 ruby18)

      expected_order = known_runtimes.dup

      client.runtimes.size.times do
        with_output do |str|
          if known_runtimes.include? str
            expected_order.first.should == str
            expected_order.shift
          end
        end
      end

      expected_order.size.should == 0
    end
  end
end
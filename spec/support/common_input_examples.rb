shared_examples_for 'inputs must have descriptions' do
  describe 'inputs' do
    subject { command.inputs }

    it "is not missing any descriptions" do
      subject.each do |_, attrs|
        next if attrs[:hidden]

        expect(attrs[:description]).to be
        expect(attrs[:description].strip).to_not be_empty
      end
    end
  end
end
RSpec.describe Vidar::Interpolation do
  describe ".call" do
    let(:string) { "http://github.local/{{github}}/{{namespace}}/{{foo}}/{{}}" }

    subject { described_class.call(string, Vidar::Config) }

    it do
      expect(subject).to eq("http://github.local/RenoFi/vidar/vidar/{{foo}}/{{}}")
    end
  end
end

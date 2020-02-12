RSpec.describe Vidar::Interpolation do
  describe ".call" do
    subject { described_class.call(string, Vidar::Config) }

    let(:string) { "http://github.local/{{github}}/{{namespace}}/{{foo}}/{{}}" }

    specify do
      expect(subject).to eq("http://github.local/RenoFi/vidar/vidar/{{foo}}/{{}}")
    end
  end
end

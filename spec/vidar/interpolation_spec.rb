RSpec.describe Vidar::Interpolation do
  describe ".call" do
    subject { described_class.call(string, Vidar::Config) }

    let(:string) { "http://github.local/{{github}}/{{namespace}}/{{foo}}/{{}}/{{FOOBAR}}/{{FOOBAR2}}" }

    before do
      ENV['FOOBAR'] = 'boomboom'
    end

    after do
      ENV['FOOBAR'] = nil
    end

    specify do
      expect(subject).to eq("http://github.local/RenoFi/vidar/vidar/{{foo}}/{{}}/boomboom/{{FOOBAR2}}")
    end
  end
end

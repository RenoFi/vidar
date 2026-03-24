RSpec.describe Vidar::Interpolation do
  describe ".call" do
    subject { described_class.call(string, Vidar::Config) }

    let(:string) { "http://github.local/{{github}}/{{namespace}}/{{foo}}/{{}}/{{FOOBAR}}/{{FOOBAR2}}" }

    before { ENV["FOOBAR"] = "boomboom" }
    after { ENV.delete("FOOBAR") }

    specify do
      expect(subject).to eq("http://github.local/RenoFi/vidar/vidar/{{foo}}/{{}}/boomboom/{{FOOBAR2}}")
    end

    context "when string is nil" do
      let(:string) { nil }
      it { expect(subject).to be_nil }
    end

    context "when string has no interpolation tokens" do
      let(:string) { "https://plain-url.example.com" }
      it { expect(subject).to eq("https://plain-url.example.com") }
    end

    context "when getter does not respond to get" do
      it "raises ArgumentError" do
        expect { described_class.call("{{foo}}", Object.new) }.to raise_error(ArgumentError, /getter must respond_to get/)
      end
    end

    context "when token matches an ENV variable" do
      before { ENV["MY_TOKEN"] = "env-value" }
      after { ENV.delete("MY_TOKEN") }

      it "substitutes the ENV value" do
        expect(described_class.call("{{MY_TOKEN}}", Vidar::Config)).to eq("env-value")
      end
    end
  end
end

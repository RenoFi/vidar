RSpec.describe Vidar::Config do
  describe ".load" do
    it do
      expect(described_class.data).not_to be_nil
      expect(described_class.data).not_to be_empty
      expect(described_class.data["github"]).to eq("RenoFi/vidar")
    end
  end

  describe ".manifest_file" do
    it do
      expect(described_class.manifest_file).to eq("vidar.yml")
      described_class.manifest_file = File.expand_path("./fixtures/vidar.yml", __dir__)
      expect(described_class.manifest_file).to eq(File.expand_path("./fixtures/vidar.yml", __dir__))
    end
  end

  describe ".get" do
    it do
      expect(described_class.get("github")).to eq("RenoFi/vidar")
      expect(described_class.get("default_branch")).to eq("master")
      expect(described_class.get("invalid")).to eq(nil)
    end
  end

  describe ".get!" do
    it do
      expect(described_class.get!("github")).to eq("RenoFi/vidar")
      expect(described_class.get!("default_branch")).to eq("master")
      expect { described_class.get!("invalid") }.to raise_error(Vidar::MissingConfigError)
    end
  end

  describe '.build_url' do
    subject { described_class.build_url }

    specify { expect(subject).to eq nil }

    context 'when build_url is defined in yaml' do
      let(:env_key) { 'TRAVIS_BUILD_WEB_URL' }
      let(:env_value) { nil }

      before do
        allow(described_class).to receive(:get).with(:build_env) { env_key }
        allow(ENV).to receive(:[]).with(env_key) { env_value }
      end

      specify { expect(subject).to eq nil }

      context 'when ENV[build_url] is set to a URL' do
        let(:env_value) { 'https://ci.company.com/builds/123' }

        specify { expect(subject).to eq env_value }
      end

      context 'when ENV[build_url] is set to a blank string' do
        let(:env_value) { '' }

        specify { expect(subject).to eq nil }
      end
    end
  end
end

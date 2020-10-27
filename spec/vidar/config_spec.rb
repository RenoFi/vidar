RSpec.describe Vidar::Config do
  describe ".load" do
    specify do
      expect(described_class.data).not_to be_nil
      expect(described_class.data).not_to be_empty
      expect(described_class.data["github"]).to eq("RenoFi/vidar")
    end
  end

  describe ".manifest_file" do
    specify do
      expect(described_class.manifest_file).to eq("vidar.yml")
      described_class.manifest_file = File.expand_path("./fixtures/vidar.yml", __dir__)
      expect(described_class.manifest_file).to eq(File.expand_path("./fixtures/vidar.yml", __dir__))
    end
  end

  describe ".get" do
    specify do
      expect(described_class.get("github")).to eq("RenoFi/vidar")
      expect(described_class.get("default_branch")).to eq("master")
      expect(described_class.get("invalid")).to eq(nil)
    end
  end

  describe ".get!" do
    specify do
      expect(described_class.get!("github")).to eq("RenoFi/vidar")
      expect(described_class.get!("default_branch")).to eq("master")
      expect { described_class.get!("invalid") }.to raise_error(Vidar::MissingConfigError)
    end
  end

  describe '.build_url' do
    subject { described_class.build_url }

    specify { expect(subject).to eq nil }

    context 'when build_env or build_url is defined in yaml' do
      let(:build_env_key) { nil }
      let(:build_env_value) { nil }
      let(:build_url) { nil }

      before do
        allow(described_class).to receive(:get).with(:build_env) { build_env_key }
        allow(described_class).to receive(:get).with(:build_url) { build_url }
        ENV[build_env_key] = build_env_value if build_env_key
      end

      after do
        ENV[build_env_key] = 'https://ci.company.com/builds/123' if build_env_key
      end

      context 'when ENV[build_url] is set to a URL' do
        let(:build_env_key) { 'VIDAR_TEST_BUILD_WEB_URL' }
        let(:build_env_value) { 'https://ci.company.com/builds/123' }

        specify { expect(subject).to eq build_env_value }
      end

      context 'when ENV[build_url] is set to a blank string' do
        let(:build_env_key) { 'TRAVIS_BUILD_WEB_URL' }
        let(:build_env_value) { '' }

        specify { expect(subject).to eq nil }
      end

      context 'when build_url is set' do
        let(:build_url) { "http://ci.company.com/asdf1234" }

        specify { expect(subject).to eq "http://ci.company.com/asdf1234" }
      end
    end
  end
end

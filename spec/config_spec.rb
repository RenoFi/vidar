RSpec.describe Vidar::Config do
  describe ".load" do
    before do
      described_class.load(File.expand_path("./fixtures/vidar.yml", __dir__))
    end

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
    before do
      described_class.manifest_file = File.expand_path("./fixtures/vidar.yml", __dir__)
    end

    it do
      expect(described_class.get("github")).to eq("RenoFi/vidar")
      expect(described_class.get("default_branch")).to eq("master")
      expect { described_class.get("invalid") }.to raise_error(Vidar::MissingConfigError)
    end
  end
end

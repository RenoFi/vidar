RSpec.describe Vidar::Config do
  describe ".load" do
    specify do
      expect(described_class.data).not_to be_nil
      expect(described_class.data).not_to be_empty
      expect(described_class.data["github"]).to eq("RenoFi/vidar")
    end
  end

  describe "schema validation" do
    let(:tmp_file) { Tempfile.new(["vidar", ".yml"]) }

    after { tmp_file.unlink }

    context "when a required key is missing" do
      before { tmp_file.write({"namespace" => "x", "github" => "x"}.to_yaml) && tmp_file.flush }

      it "raises an error listing the missing key" do
        expect { described_class.load(tmp_file.path) }.to raise_error(Vidar::Error, /image/)
      end
    end

    context "when deployments is not a Hash" do
      before { tmp_file.write({"image" => "x", "namespace" => "x", "github" => "x", "deployments" => "bad"}.to_yaml) && tmp_file.flush }

      it "raises an error" do
        expect { described_class.load(tmp_file.path) }.to raise_error(Vidar::Error, /deployments/)
      end
    end

    context "when a deployment entry is missing name" do
      before do
        tmp_file.write({"image" => "x", "namespace" => "x", "github" => "x", "deployments" => {"ctx" => {"url" => "http://x"}}}.to_yaml)
        tmp_file.flush
      end

      it "raises an error" do
        expect { described_class.load(tmp_file.path) }.to raise_error(Vidar::Error, /name/)
      end
    end
  end

  describe ".honeycomb_env_api_key" do
    before { ENV["HONEYCOMB_API_KEY_STAGING"] = "secret" }
    after { ENV.delete("HONEYCOMB_API_KEY_STAGING") }

    it "returns the env var for the given environment" do
      expect(described_class.honeycomb_env_api_key("staging")).to eq("secret")
    end

    it "returns nil when env var is not set" do
      expect(described_class.honeycomb_env_api_key("production")).to be_nil
    end
  end

  describe ".deploy_config" do
    before { described_class.instance_variable_set(:@deploy_configs, {}) }

    context "when a matching deployment context exists" do
      before do
        described_class.instance_variable_set(:@data, {
          "image" => "my-app",
          "namespace" => "staging",
          "github" => "org/repo",
          "deployments" => {
            "test-context" => {"name" => "Staging", "url" => "https://k8s.example.com"}
          }
        })
        allow(described_class).to receive(:get!).with(:kubectl_context).and_return("test-context")
      end

      it "returns a DeployConfig" do
        expect(described_class.deploy_config).to be_a(Vidar::DeployConfig)
      end

      it "has the correct name" do
        expect(described_class.deploy_config.name).to eq("Staging")
      end
    end

    context "when no matching deployment context is found" do
      before do
        described_class.instance_variable_set(:@data, {
          "image" => "x", "namespace" => "x", "github" => "x"
        })
        allow(described_class).to receive(:get!).with(:kubectl_context).and_return("unknown-context")
      end

      it "returns nil and logs an error" do
        expect { described_class.deploy_config }.to output(/could not find deployment config/).to_stdout
      end
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
      expect(described_class.get("default_branch")).to eq("main")
      expect(described_class.get("invalid")).to be_nil
    end
  end

  describe ".get!" do
    specify do
      expect(described_class.get!("github")).to eq("RenoFi/vidar")
      expect(described_class.get!("default_branch")).to eq("main")
      expect { described_class.get!("invalid") }.to raise_error(Vidar::MissingConfigError)
    end
  end

  describe ".build_url" do
    subject { described_class.build_url }

    specify { expect(subject).to be_nil }

    context "when build_env or build_url is defined in yaml" do
      let(:build_env_key) { nil }
      let(:build_env_value) { nil }
      let(:build_url) { nil }

      before do
        allow(described_class).to receive(:get).with(:build_env) { build_env_key }
        allow(described_class).to receive(:get).with(:build_url) { build_url }
        ENV[build_env_key] = build_env_value if build_env_key
      end

      after do
        ENV[build_env_key] = "https://ci.company.com/builds/123" if build_env_key
      end

      context "when ENV[build_url] is set to a URL" do
        let(:build_env_key) { "VIDAR_TEST_BUILD_WEB_URL" }
        let(:build_env_value) { "https://ci.company.com/builds/123" }

        specify { expect(subject).to eq build_env_value }
      end

      context "when ENV[build_url] is set to a blank string" do
        let(:build_env_key) { "TRAVIS_BUILD_WEB_URL" }
        let(:build_env_value) { "" }

        specify { expect(subject).to be_nil }
      end

      context "when build_url is set" do
        let(:build_url) { "http://ci.company.com/asdf1234" }

        specify { expect(subject).to eq "http://ci.company.com/asdf1234" }
      end
    end
  end
end

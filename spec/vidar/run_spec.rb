RSpec.describe Vidar::Run do
  let(:deploy_config) { instance_double(Vidar::DeployConfig, https_proxy: nil) }

  before { allow(Vidar::Config).to receive(:deploy_config).and_return(deploy_config) }

  describe ".kubectl_envs_hash" do
    context "when no https_proxy is configured" do
      it "returns an empty hash" do
        expect(described_class.kubectl_envs_hash).to eq({})
      end
    end

    context "when https_proxy is configured" do
      let(:deploy_config) { instance_double(Vidar::DeployConfig, https_proxy: "http://proxy.internal:3128") }

      it "returns hash with HTTPS_PROXY key" do
        expect(described_class.kubectl_envs_hash).to eq({"HTTPS_PROXY" => "http://proxy.internal:3128"})
      end
    end
  end

  describe ".kubectl_envs_string" do
    context "when no https_proxy is configured" do
      it "returns an empty string" do
        expect(described_class.kubectl_envs_string).to eq("")
      end
    end

    context "when https_proxy is configured" do
      let(:deploy_config) { instance_double(Vidar::DeployConfig, https_proxy: "http://proxy.internal:3128") }

      it "returns HTTPS_PROXY= prefixed string" do
        expect(described_class.kubectl_envs_string).to eq("HTTPS_PROXY=http://proxy.internal:3128 ")
      end
    end
  end

  describe ".kubectl_capture3" do
    let(:namespace) { "staging" }

    before do
      allow(Vidar::Config).to receive(:get!).with(:namespace).and_return(namespace)
    end

    it "calls kubectl with the namespace flag" do
      expect(Open3).to receive(:capture3)
        .with({}, "kubectl", "-n", "staging", "get", "pods")
        .and_return(["output", "", double(success?: true)])

      described_class.kubectl_capture3("get pods", namespace: "staging")
    end

    it "returns stdout, stderr, and status" do
      allow(Open3).to receive(:capture3).and_return(["out", "err", double(success?: true)])
      stdout, stderr, status = described_class.kubectl_capture3("get pods", namespace: "staging")
      expect(stdout).to eq("out")
      expect(stderr).to eq("err")
      expect(status.success?).to be(true)
    end
  end
end

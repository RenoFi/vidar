RSpec.describe Vidar::HoneycombNotification do
  subject do
    described_class.new(
      github:        "RenoFi/vidar",
      revision:      "059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd",
      revision_name: "Release 1.0.0",
      build_url:     "https://ci.company.com/builds/123",
      deploy_config: deploy_config,
      api_key:       api_key,
    )
  end

  let(:deploy_config) do
    Vidar::DeployConfig.new(
      name: "staging",
      url: "https://console.cloud.google.com/kubernetes/workload?namespace=foo",
      honeycomb_dataset: dataset,
    )
  end

  let(:api_key) { "secret" }
  let(:dataset) { "foo" }

  context "when not configured" do
    let(:dataset) { nil }

    it "does not send a success notification" do
      expect(subject.success).to be(false)
    end

    it "does not send a failure notification" do
      expect(subject.failure).to be(false)
    end
  end

  describe "#success" do
    it "sends a notification" do
      stub_request(:post, "https://api.honeycomb.io/1/markers/foo")
        .with(headers: { "Content-Type" => "application/json", "X-Honeycomb-Team" => "secret" })
        .to_return(status: 201)

      expect(subject.success).to be(true)
    end
  end

  describe "#failure" do
    it "sends a notification" do
      stub_request(:post, "https://api.honeycomb.io/1/markers/foo")
        .with(headers: { "Content-Type" => "application/json", "X-Honeycomb-Team" => "secret" })
        .to_return(status: 201)

      expect(subject.failure).to be(true)
    end
  end
end

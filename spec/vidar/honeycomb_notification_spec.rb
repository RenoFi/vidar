RSpec.describe Vidar::HoneycombNotification do
  subject do
    described_class.new(
      github:        "RenoFi/vidar",
      revision:      "059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd",
      revision_name: "Release 1.0.0",
      build_url:     "https://ci.company.com/builds/123",
      deploy_config:,
      api_key:,
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
    before do
      ENV["HONEYCOMB_API_KEY_FOO"] = "foo-secret"
    end

    it "sends a notification" do
      create_legacy_marker = stub_request(:post, "https://api.honeycomb.io/1/markers/foo")
        .with(headers: { "Content-Type" => "application/json", "X-Honeycomb-Team" => "secret" })
        .to_return(status: 201)

      create_marker = stub_request(:post, "https://api.honeycomb.io/1/markers/__all__")
        .with(headers: { "Content-Type" => "application/json", "X-Honeycomb-Team" => "foo-secret" })
        .to_return(status: 201)

      expect(subject.success).to be(true)
      expect(create_legacy_marker).to have_been_requested
      expect(create_marker).to have_been_requested
    end
  end

  describe "#failure" do
    it "sends a notification" do
      create_legacy_marker = stub_request(:post, "https://api.honeycomb.io/1/markers/foo")
        .with(headers: { "Content-Type" => "application/json", "X-Honeycomb-Team" => "secret" })
        .to_return(status: 201)

      create_marker = stub_request(:post, "https://api.honeycomb.io/1/markers/__all__")
        .with(headers: { "Content-Type" => "application/json", "X-Honeycomb-Team" => "foo-secret" })
        .to_return(status: 201)

      expect(subject.failure).to be(true)
      expect(create_legacy_marker).to have_been_requested
      expect(create_marker).to have_been_requested
    end
  end
end

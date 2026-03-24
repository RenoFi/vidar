RSpec.describe Vidar::HoneycombNotification do
  subject do
    described_class.new(
      github: "RenoFi/vidar",
      revision: "059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd",
      revision_name: "Release 1.0.0",
      build_url: "https://ci.company.com/builds/123",
      deploy_config:,
      api_key:
    )
  end

  let(:deploy_config) do
    Vidar::DeployConfig.new(
      name: "staging",
      url: "https://console.cloud.google.com/kubernetes/workload?namespace=foo",
      honeycomb_dataset: dataset
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
    before { ENV["HONEYCOMB_API_KEY_FOO"] = "foo-secret" }
    after { ENV.delete("HONEYCOMB_API_KEY_FOO") }

    it "sends a notification" do
      create_legacy_marker = stub_request(:post, "https://api.honeycomb.io/1/markers/foo")
        .with(headers: {"Content-Type" => "application/json", "X-Honeycomb-Team" => "secret"})
        .to_return(status: 201)

      create_marker = stub_request(:post, "https://api.honeycomb.io/1/markers/__all__")
        .with(headers: {"Content-Type" => "application/json", "X-Honeycomb-Team" => "foo-secret"})
        .to_return(status: 201)

      expect(subject.success).to be(true)
      expect(create_legacy_marker).to have_been_requested
      expect(create_marker).to have_been_requested
    end
  end

  describe "#failure" do
    before { ENV["HONEYCOMB_API_KEY_FOO"] = "foo-secret" }
    after { ENV.delete("HONEYCOMB_API_KEY_FOO") }

    it "sends a notification" do
      create_legacy_marker = stub_request(:post, "https://api.honeycomb.io/1/markers/foo")
        .with(headers: {"Content-Type" => "application/json", "X-Honeycomb-Team" => "secret"})
        .to_return(status: 201)

      create_marker = stub_request(:post, "https://api.honeycomb.io/1/markers/__all__")
        .with(headers: {"Content-Type" => "application/json", "X-Honeycomb-Team" => "foo-secret"})
        .to_return(status: 201)

      expect(subject.failure).to be(true)
      expect(create_legacy_marker).to have_been_requested
      expect(create_marker).to have_been_requested
    end
  end

  describe "when the legacy marker endpoint returns a non-201 status" do
    before do
      stub_request(:post, "https://api.honeycomb.io/1/markers/foo").to_return(status: 500, body: "Server Error")
      stub_request(:post, "https://api.honeycomb.io/1/markers/__all__").to_return(status: 201)
    end

    it "warns about the failure" do
      expect { subject.failure }.to output(/Honeycomb marker not created/).to_stderr
    end

    it "returns false for the legacy marker" do
      # create_legacy_marker returns false; create_marker (no env key) returns false
      expect(subject.failure).to be(false)
    end
  end

  describe "when a network error occurs on the legacy marker" do
    before do
      stub_request(:post, "https://api.honeycomb.io/1/markers/foo")
        .to_raise(Faraday::ConnectionFailed.new("connection refused"))
      stub_request(:post, "https://api.honeycomb.io/1/markers/__all__").to_return(status: 201)
    end

    it "does not raise" do
      expect { subject.success }.not_to raise_error
    end

    it "warns about the failure" do
      expect { subject.success }.to output(/Honeycomb legacy marker request failed/).to_stderr
    end
  end

  describe "when a network error occurs on the env marker" do
    before do
      ENV["HONEYCOMB_API_KEY_FOO"] = "foo-secret"
      stub_request(:post, "https://api.honeycomb.io/1/markers/foo").to_return(status: 201)
      stub_request(:post, "https://api.honeycomb.io/1/markers/__all__").to_raise(Faraday::TimeoutError)
    end

    after { ENV.delete("HONEYCOMB_API_KEY_FOO") }

    it "does not raise" do
      expect { subject.success }.not_to raise_error
    end

    it "warns about the failure" do
      expect { subject.success }.to output(/Honeycomb env marker request failed/).to_stderr
    end
  end

  describe "when api_key is nil" do
    let(:api_key) { nil }

    before { ENV.delete("HONEYCOMB_API_KEY_FOO") }

    it "is not configured" do
      expect(subject.configured?).to be(false)
    end

    it "does not make any HTTP requests" do
      expect { subject.success }.not_to raise_error
      expect(a_request(:post, /honeycomb/)).not_to have_been_made
    end
  end
end

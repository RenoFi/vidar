RSpec.describe Vidar::SentryNotification do
  let(:webhook_url) { "https://sentry.io/api/hooks/release/builtin/123/abc/" }
  let(:deploy_config) { Vidar::DeployConfig.new(name: "staging", sentry_webhook_url: webhook_url) }

  subject { described_class.new(revision: "abc123", deploy_config:) }

  describe "#configured?" do
    context "when webhook_url is present" do
      it { expect(subject.configured?).to be(true) }
    end

    context "when webhook_url is nil" do
      let(:deploy_config) { Vidar::DeployConfig.new(name: "staging") }
      it { expect(subject.configured?).to be(false) }
    end

    context "when webhook_url is empty string" do
      let(:deploy_config) { Vidar::DeployConfig.new(name: "staging", sentry_webhook_url: "") }
      it { expect(subject.configured?).to be(false) }
    end
  end

  describe "#call" do
    it "posts the revision to the webhook URL" do
      stub = stub_request(:post, webhook_url)
        .with(body: {version: "abc123"}.to_json, headers: {"Content-Type" => "application/json"})
        .to_return(status: 200)

      subject.call

      expect(stub).to have_been_requested
    end

    it "returns a Faraday::Response on success" do
      stub_request(:post, webhook_url).to_return(status: 200)
      expect(subject.call).to be_a(Faraday::Response)
    end

    context "when the request fails with a network error" do
      before do
        stub_request(:post, webhook_url).to_raise(Faraday::ConnectionFailed.new("connection refused"))
      end

      it "does not raise" do
        expect { subject.call }.not_to raise_error
      end

      it "returns nil" do
        expect(subject.call).to be_nil
      end

      it "warns about the failure" do
        expect { subject.call }.to output(/Sentry notification request failed/).to_stderr
      end
    end

    context "when the request times out" do
      before { stub_request(:post, webhook_url).to_raise(Faraday::TimeoutError) }

      it "does not raise" do
        expect { subject.call }.not_to raise_error
      end
    end
  end
end

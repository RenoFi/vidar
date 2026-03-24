RSpec.describe Vidar::SlackNotification do
  subject do
    described_class.new(
      github: "RenoFi/vidar",
      revision: "059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd",
      revision_name: "Release 1.0.0",
      build_url: "https://ci.company.com/builds/123",
      deploy_config:
    )
  end

  let(:connection) { instance_double(Faraday) }
  let(:webhook_url) { "https://slack.local/fake" }

  let(:deploy_config) do
    Vidar::DeployConfig.new(
      name: "staging",
      url: "https://console.cloud.google.com/kubernetes/workload?namespace=foo",
      slack_webhook_url: webhook_url
    )
  end

  describe "#configured?" do
    context "when webhook_url is present?" do
      it { expect(subject.configured?).to be(true) }
    end

    context "when webhook_url is blank?" do
      let(:webhook_url) { nil }

      it { expect(subject.configured?).to be(false) }
    end
  end

  describe "#failure" do
    let(:expected_data) do
      {
        attachments: [
          {
            title: "RenoFi/vidar",
            title_link: "https://github.com/RenoFi/vidar/commit/059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd",
            color: "ff1100",
            text: "<!channel> Failed deploy of " \
                  "<https://github.com/RenoFi/vidar/commit/059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd|Release 1.0.0> " \
                  "to " \
                  "<https://console.cloud.google.com/kubernetes/workload?namespace=foo|staging>." \
                  "\n" \
                  "<https://ci.company.com/builds/123|View the build.>",
            fallback: "<!channel> Failed deploy of " \
                      "<https://github.com/RenoFi/vidar/commit/059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd|Release 1.0.0> " \
                      "to " \
                      "<https://console.cloud.google.com/kubernetes/workload?namespace=foo|staging>." \
                      "\n" \
                      "<https://ci.company.com/builds/123|View the build.>"
          }
        ]
      }
    end

    specify do
      stub_request(:post, "https://slack.local/fake")
        .with(body: expected_data.to_json, headers: {"Content-Type" => "application/json"})
      expect(subject.failure).to be_a(Faraday::Response)
    end
  end

  describe "#deliver" do
    it "posts a custom message" do
      stub = stub_request(:post, "https://slack.local/fake")
        .with(headers: {"Content-Type" => "application/json"})
        .to_return(status: 200)

      subject.deliver(message: "Custom message", color: "aabbcc")

      expect(stub).to have_been_requested
    end

    it "uses the default color when none is specified" do
      stub = stub_request(:post, "https://slack.local/fake").to_return(status: 200)

      subject.deliver(message: "Custom message")

      expect(stub).to have_been_requested
    end
  end

  describe "when a network error occurs" do
    before do
      stub_request(:post, "https://slack.local/fake").to_raise(Faraday::ConnectionFailed.new("refused"))
    end

    it "does not raise" do
      expect { subject.failure }.not_to raise_error
    end

    it "returns nil" do
      expect(subject.failure).to be_nil
    end

    it "warns about the failure" do
      expect { subject.failure }.to output(/Slack notification request failed/).to_stderr
    end
  end

  describe "#success" do
    let(:expected_data) do
      {
        attachments: [
          {
            title: "RenoFi/vidar",
            title_link: "https://github.com/RenoFi/vidar/commit/059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd",
            color: "008800",
            text: "Successful deploy of " \
                  "<https://github.com/RenoFi/vidar/commit/059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd|Release 1.0.0> " \
                  "to " \
                  "<https://console.cloud.google.com/kubernetes/workload?namespace=foo|staging>." \
                  "\n" \
                  "<https://ci.company.com/builds/123|View the build.>",
            fallback: "Successful deploy of <https://github.com/RenoFi/vidar/commit/059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd|Release 1.0.0> " \
                      "to " \
                      "<https://console.cloud.google.com/kubernetes/workload?namespace=foo|staging>." \
                      "\n" \
                      "<https://ci.company.com/builds/123|View the build.>"
          }
        ]
      }
    end

    specify do
      stub_request(:post, "https://slack.local/fake")
        .with(body: expected_data.to_json, headers: {"Content-Type" => "application/json"})
      expect(subject.success).to be_a(Faraday::Response)
    end
  end
end

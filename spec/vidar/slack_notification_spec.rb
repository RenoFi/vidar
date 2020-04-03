RSpec.describe Vidar::SlackNotification do
  subject do
    described_class.new(
      github:        "RenoFi/vidar",
      revision:      "059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd",
      revision_name: "Release 1.0.0",
      build_url:     "https://ci.company.com/builds/123",
      deploy_config: deploy_config,
    )
  end

  let(:webhook_url) { "https://slack.local/asdf1234" }

  let(:deploy_config) do
    Vidar::DeployConfig.new(
      name: "staging",
      url: "https://console.cloud.google.com/kubernetes/workload?namespace=foo",
      slack_webhook_url: webhook_url)
  end

  describe "#configured?" do
    context "when webhook_url is present?" do
      it { expect(subject.configured?).to eq(true) }
    end

    context "when webhook_url is blank?" do
      let(:webhook_url) { nil }

      it { expect(subject.configured?).to eq(false) }
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
            text: "Failed deploy of <https://github.com/RenoFi/vidar/commit/059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd|Release 1.0.0> to <https://console.cloud.google.com/kubernetes/workload?namespace=foo|staging> :fire: <!channel> <https://ci.company.com/builds/123|View the build on ci.company.com>", # rubocop:disable Layout/LineLength
            fallback: "Failed deploy of <https://github.com/RenoFi/vidar/commit/059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd|Release 1.0.0> to <https://console.cloud.google.com/kubernetes/workload?namespace=foo|staging> :fire: <!channel> <https://ci.company.com/builds/123|View the build on ci.company.com>" # rubocop:disable Layout/LineLength
          }
        ]
      }
    end

    before do
      expect(subject).to receive(:perform_with).with(expected_data)
    end

    specify do
      subject.failure
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
              "<https://github.com/RenoFi/vidar/commit/059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd|Release 1.0.0>" \
              " to " \
              "<https://console.cloud.google.com/kubernetes/workload?namespace=foo|staging>. " \
              "<https://ci.company.com/builds/123|View the build on ci.company.com>",
            fallback: "Successful deploy of <https://github.com/RenoFi/vidar/commit/059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd|Release 1.0.0>" \
              " to " \
              "<https://console.cloud.google.com/kubernetes/workload?namespace=foo|staging>. " \
              "<https://ci.company.com/builds/123|View the build on ci.company.com>"
          }
        ]
      }
    end

    before do
      expect(subject).to receive(:perform_with).with(expected_data)
    end

    specify do
      subject.success
    end
  end
end

RSpec.describe Vidar::SlackNotification do

  let(:webhook_url) { "https://slack.local/asdf1234" }

  let(:deploy_config) do
    Vidar::DeployConfig.new(
      name: "staging",
      url: "https://console.cloud.google.com/kubernetes/workload?namespace=foo",
      slack_webhook_url: webhook_url)
  end

  subject do
    described_class.new(
      github:        "RenoFi/vidar",
      revision:      "059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd",
      revision_name: "Release 1.0.0",
      deploy_config: deploy_config,
    )
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
            text: "Failed deploy of <https://github.com/RenoFi/vidar/commit/059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd|Release 1.0.0> to <https://console.cloud.google.com/kubernetes/workload?namespace=foo|staging> :fire: <!channel>", # rubocop:disable Metrics/LineLength
            fallback: "Failed deploy of <https://github.com/RenoFi/vidar/commit/059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd|Release 1.0.0> to <https://console.cloud.google.com/kubernetes/workload?namespace=foo|staging> :fire: <!channel>" # rubocop:disable Metrics/LineLength
          }
        ]
      }
    end

    it do
      expect(subject).to receive(:perform_with).with(expected_data)
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
            text: "Successful deploy of <https://github.com/RenoFi/vidar/commit/059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd|Release 1.0.0> to <https://console.cloud.google.com/kubernetes/workload?namespace=foo|staging>", # rubocop:disable Metrics/LineLength
            fallback: "Successful deploy of <https://github.com/RenoFi/vidar/commit/059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd|Release 1.0.0> to <https://console.cloud.google.com/kubernetes/workload?namespace=foo|staging>" # rubocop:disable Metrics/LineLength
          }
        ]
      }
    end

    it do
      expect(subject).to receive(:perform_with).with(expected_data)
      subject.success
    end
  end
end

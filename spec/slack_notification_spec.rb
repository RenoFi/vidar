RSpec.describe Vidar::SlackNotification do

  let(:webhook_url) { "https://slack.local/asdf1234" }

  subject do
    described_class.new(
      webhook_url:   webhook_url,
      github:        "RenoFi/vidar",
      revision:      "059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd",
      revision_name: "Release 1.0.0",
      cluster_label: "staging",
      cluster_url:   "https://console.cloud.google.com/kubernetes/workload",
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

  describe "#error" do
    let(:expected_data) do
      {
        attachments: [
          {
            title: "RenoFi/vidar",
            title_link: "https://github.com/RenoFi/vidar/commit/059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd",
            color: "danger",
            text: "Failed deploy of <https://github.com/RenoFi/vidar/commit/059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd|Release 1.0.0> to <https://console.cloud.google.com/kubernetes/workload|staging> :fire: <!channel>", # rubocop:disable Metrics/LineLength
            fallback: "Failed deploy of <https://github.com/RenoFi/vidar/commit/059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd|Release 1.0.0> to <https://console.cloud.google.com/kubernetes/workload|staging> :fire: <!channel>" # rubocop:disable Metrics/LineLength
          }
        ]
      }
    end

    it do
      expect(subject).to receive(:perform_with).with(expected_data)
      subject.error
    end
  end

  describe "#success" do
    let(:expected_data) do
      {
        attachments: [
          {
            title: "RenoFi/vidar",
            title_link: "https://github.com/RenoFi/vidar/commit/059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd",
            color: "good",
            text: "Successful deploy of <https://github.com/RenoFi/vidar/commit/059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd|Release 1.0.0> to <https://console.cloud.google.com/kubernetes/workload|staging>", # rubocop:disable Metrics/LineLength
            fallback: "Successful deploy of <https://github.com/RenoFi/vidar/commit/059082da8b8733d46a9a9a3d82e3a7afa8cf8cbd|Release 1.0.0> to <https://console.cloud.google.com/kubernetes/workload|staging>" # rubocop:disable Metrics/LineLength
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

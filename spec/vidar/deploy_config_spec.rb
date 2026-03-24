RSpec.describe Vidar::DeployConfig do
  subject { described_class.new(options) }

  let(:options) do
    {
      name: "staging",
      url: "https://console.cloud.google.com",
      slack_webhook_url: "https://hooks.slack.com/abc",
      sentry_webhook_url: "https://sentry.io/hook",
      honeycomb_dataset: "my-app",
      https_proxy: "http://proxy.internal:3128",
      default_color: "aaaaaa",
      success_color: "00ff00",
      failure_color: "ff0000"
    }
  end

  it { expect(subject.name).to eq("staging") }
  it { expect(subject.url).to eq("https://console.cloud.google.com") }
  it { expect(subject.slack_webhook_url).to eq("https://hooks.slack.com/abc") }
  it { expect(subject.sentry_webhook_url).to eq("https://sentry.io/hook") }
  it { expect(subject.honeycomb_dataset).to eq("my-app") }
  it { expect(subject.https_proxy).to eq("http://proxy.internal:3128") }
  it { expect(subject.default_color).to eq("aaaaaa") }
  it { expect(subject.success_color).to eq("00ff00") }
  it { expect(subject.failure_color).to eq("ff0000") }

  context "with defaults" do
    subject { described_class.new(name: "staging") }

    it { expect(subject.url).to be_nil }
    it { expect(subject.slack_webhook_url).to be_nil }
    it { expect(subject.sentry_webhook_url).to be_nil }
    it { expect(subject.honeycomb_dataset).to be_nil }
    it { expect(subject.https_proxy).to be_nil }
    it { expect(subject.default_color).to eq(Vidar::DeployConfig::DEFAULT_COLOR) }
    it { expect(subject.success_color).to eq(Vidar::DeployConfig::SUCCESS_COLOR) }
    it { expect(subject.failure_color).to eq(Vidar::DeployConfig::FAILURE_COLOR) }
  end

  context "when name is missing" do
    it "raises KeyError" do
      expect { described_class.new({}) }.to raise_error(KeyError)
    end
  end
end

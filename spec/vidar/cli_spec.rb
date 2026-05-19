RSpec.describe Vidar::CLI do
  describe "monitor_deploy_status" do
    let(:deploy_status) { instance_double(Vidar::DeployStatus, wait_until_completed: nil, success?: true) }
    let(:slack_notification) { instance_double(Vidar::SlackNotification, configured?: false) }
    let(:honeycomb_notification) { instance_double(Vidar::HoneycombNotification, success: nil) }
    let(:sentry_notification) { instance_double(Vidar::SentryNotification, configured?: false) }
    let(:deploy_config) { Vidar::DeployConfig.new(name: "staging") }

    before do
      allow(Vidar::Config).to receive(:get!).and_call_original
      allow(Vidar::Config).to receive(:get!).with(:revision).and_return("abc123")
      allow(Vidar::Config).to receive(:get!).with(:kubectl_context).and_return("staging")
      allow(Vidar::Config).to receive(:deploy_config).and_return(deploy_config)
      allow(Vidar::DeployStatus).to receive(:new).and_return(deploy_status)
      allow(Vidar::SlackNotification).to receive(:get).and_return(slack_notification)
      allow(Vidar::HoneycombNotification).to receive(:get).and_return(honeycomb_notification)
      allow(Vidar::SentryNotification).to receive(:new).and_return(sentry_notification)
    end

    it "invokes notify_sentry without forwarding parent options as positional args" do
      expect(Vidar::SentryNotification).to receive(:new).with(revision: "abc123", deploy_config:)

      expect { Vidar::CLI.start(["monitor_deploy_status", "--max_tries=1"]) }.not_to raise_error
    end
  end
end

RSpec.describe Vidar::K8s::Container do
  let(:base_data) do
    {"name" => "web", "ready" => false, "state" => {}, "namespace" => "staging", "kind" => nil, "pod_name" => "web-abc"}
  end

  subject { described_class.new(base_data) }

  describe "#deployed?" do
    context "when running and ready" do
      let(:base_data) { super().merge("ready" => true, "state" => {"running" => {"startedAt" => "2024-01-01T00:00:00Z"}}) }
      it { expect(subject.deployed?).to be(true) }
    end

    context "when running but not ready" do
      let(:base_data) { super().merge("ready" => false, "state" => {"running" => {"startedAt" => "2024-01-01T00:00:00Z"}}) }
      it { expect(subject.deployed?).to be(false) }
    end

    context "when state is empty" do
      it { expect(subject.deployed?).to be(false) }
    end
  end

  describe "#terminated_error?" do
    context "when exit code is non-zero" do
      let(:base_data) { super().merge("state" => {"terminated" => {"exitCode" => 1}}) }
      it { expect(subject.terminated_error?).to be(true) }
    end

    context "when exit code is 0 (success)" do
      let(:base_data) { super().merge("state" => {"terminated" => {"exitCode" => 0}}) }
      it { expect(subject.terminated_error?).to be(false) }
    end

    context "when reason is Error" do
      let(:base_data) { super().merge("state" => {"terminated" => {"reason" => "Error", "exitCode" => 0}}) }
      it { expect(subject.terminated_error?).to be(true) }
    end
  end

  describe "#terminated_completed?" do
    context "when exit code is 0" do
      let(:base_data) { super().merge("state" => {"terminated" => {"exitCode" => 0}}) }
      it { expect(subject.terminated_completed?).to be(true) }
    end

    context "when reason is Completed" do
      let(:base_data) { super().merge("state" => {"terminated" => {"reason" => "Completed"}}) }
      it { expect(subject.terminated_completed?).to be(true) }
    end
  end

  describe "#sidecar?" do
    context "when name matches default sidecar list" do
      let(:base_data) { super().merge("name" => "istio-proxy") }
      it { expect(subject.sidecar?).to be(true) }
    end

    context "when name matches custom sidecar list" do
      let(:base_data) { super().merge("name" => "linkerd-proxy") }
      it { expect(subject.sidecar?(["linkerd-proxy"])).to be(true) }
    end

    context "when name is a regular container" do
      it { expect(subject.sidecar?).to be(false) }
    end
  end

  describe "#istio?" do
    context "when name is istio-proxy" do
      let(:base_data) { super().merge("name" => "istio-proxy") }
      it { expect(subject.istio?).to be(true) }
    end

    context "when name is something else" do
      it { expect(subject.istio?).to be(false) }
    end
  end

  describe "#text_statuses" do
    context "when running and ready" do
      let(:base_data) { super().merge("ready" => true, "state" => {"running" => {"startedAt" => "2024-01-01T00:00:00Z"}}) }
      it { expect(subject.text_statuses.first.to_s).to include("Ready & Running") }
    end

    context "when waiting" do
      let(:base_data) { super().merge("state" => {"waiting" => {"reason" => "ContainerCreating"}}) }
      it { expect(subject.text_statuses.first.to_s).to include("Waiting") }
    end

    context "when terminated/completed" do
      let(:base_data) { super().merge("state" => {"terminated" => {"reason" => "Completed", "exitCode" => 0}}) }
      it { expect(subject.text_statuses.first.to_s).to include("Terminated/Completed") }
    end

    context "when terminated/error" do
      let(:base_data) { super().merge("state" => {"terminated" => {"reason" => "Error", "exitCode" => 1}}) }
      it { expect(subject.text_statuses.first.to_s).to include("Terminated/Error") }
    end

    context "when state is unknown (empty)" do
      it { expect(subject.text_statuses.first.to_s).to include("Unknown") }
    end

    context "when unschedulable" do
      let(:base_data) { super().merge("reason" => "Unschedulable", "message" => "0/3 nodes available") }
      it { expect(subject.text_statuses.first.to_s).to include("Unschedulable") }
    end
  end

  describe "#unknown?" do
    context "when state is empty" do
      it { expect(subject.unknown?).to be(true) }
    end

    context "when running" do
      let(:base_data) { super().merge("state" => {"running" => {"startedAt" => "2024-01-01T00:00:00Z"}}) }
      it { expect(subject.unknown?).to be(false) }
    end

    context "when waiting" do
      let(:base_data) { super().merge("state" => {"waiting" => {}}) }
      it { expect(subject.unknown?).to be(false) }
    end
  end

  describe "#ready_and_running?" do
    context "when ready and running" do
      let(:base_data) { super().merge("ready" => true, "state" => {"running" => {"startedAt" => "2024-01-01T00:00:00Z"}}) }
      it { expect(subject.ready_and_running?).to be(true) }
    end

    context "when running but not ready" do
      let(:base_data) { super().merge("ready" => false, "state" => {"running" => {"startedAt" => "2024-01-01T00:00:00Z"}}) }
      it { expect(subject.ready_and_running?).to be(false) }
    end

    context "when ready but not running" do
      let(:base_data) { super().merge("ready" => true, "state" => {}) }
      it { expect(subject.ready_and_running?).to be(false) }
    end
  end

  describe "#job?" do
    context "when kind is Job" do
      let(:base_data) { super().merge("kind" => "Job") }
      it { expect(subject.job?).to be(true) }
    end

    context "when kind is Deployment" do
      let(:base_data) { super().merge("kind" => "Deployment") }
      it { expect(subject.job?).to be(false) }
    end

    context "when kind is nil" do
      it { expect(subject.job?).to be(false) }
    end
  end

  describe "#deployed? for a job" do
    let(:base_data) { super().merge("kind" => "Job") }

    context "when job has terminated" do
      let(:base_data) { super().merge("state" => {"terminated" => {"reason" => "Completed", "exitCode" => 0}}) }
      it { expect(subject.deployed?).to be(true) }
    end

    context "when job is still running" do
      let(:base_data) { super().merge("state" => {"running" => {"startedAt" => "2024-01-01T00:00:00Z"}}) }
      it { expect(subject.deployed?).to be(false) }
    end
  end

  describe "#success? for a job" do
    let(:base_data) { super().merge("kind" => "Job") }

    context "when job completed successfully" do
      let(:base_data) { super().merge("state" => {"terminated" => {"reason" => "Completed", "exitCode" => 0}}) }
      it { expect(subject.success?).to be(true) }
    end

    context "when job terminated with error" do
      let(:base_data) { super().merge("state" => {"terminated" => {"reason" => "Error", "exitCode" => 1}}) }
      it { expect(subject.success?).to be(false) }
    end
  end

  describe "#to_text" do
    let(:base_data) { super().merge("ready" => true, "state" => {"running" => {"startedAt" => "2024-01-01T00:00:00Z"}}) }

    it "includes namespace and name" do
      text = subject.to_text
      expect(text).to include("staging")
      expect(text).to include("web")
    end

    it "is formatted as a table row" do
      expect(subject.to_text).to match(/^\|.*\|$/)
    end
  end

  describe "#name" do
    context "when data has a name" do
      it { expect(subject.name).to eq("web") }
    end

    context "when name is nil, falls back to pod_name" do
      let(:base_data) { super().merge("name" => nil) }
      it { expect(subject.name).to eq("web-abc") }
    end
  end
end

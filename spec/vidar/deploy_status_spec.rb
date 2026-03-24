RSpec.describe Vidar::DeployStatus do
  subject { described_class.new(namespace: "staging", max_tries: 3) }

  let(:pod_set_success) do
    instance_double(Vidar::K8s::PodSet, any?: true, deployed?: true, waiting?: false, success?: true)
  end

  let(:pod_set_pending) do
    instance_double(Vidar::K8s::PodSet, any?: false, deployed?: false, waiting?: false, success?: false)
  end

  before { allow(subject).to receive(:sleep) }

  describe "#wait_until_up" do
    context "when pods appear immediately" do
      before { allow(Vidar::K8s::PodSet).to receive(:new).and_return(pod_set_success) }

      it "breaks after finding pods" do
        expect(Vidar::K8s::PodSet).to receive(:new).once
        subject.wait_until_up
      end
    end

    context "when pods never appear" do
      before { allow(Vidar::K8s::PodSet).to receive(:new).and_return(pod_set_pending) }

      it "exhausts max_tries without raising" do
        expect { subject.wait_until_up }.not_to raise_error
      end
    end
  end

  describe "#wait_until_completed" do
    context "when deployment succeeds immediately" do
      before { allow(Vidar::K8s::PodSet).to receive(:new).and_return(pod_set_success) }

      it "breaks after first successful poll" do
        expect(Vidar::K8s::PodSet).to receive(:new).once
        subject.wait_until_completed
      end
    end

    context "when deployment never completes" do
      before { allow(Vidar::K8s::PodSet).to receive(:new).and_return(pod_set_pending) }

      it "exhausts max_tries without raising" do
        expect { subject.wait_until_completed }.not_to raise_error
      end
    end
  end

  describe "#success?" do
    context "before any wait call" do
      it { expect(subject.success?).to be(false) }
    end

    context "after wait_until_completed with a successful pod set" do
      before do
        allow(Vidar::K8s::PodSet).to receive(:new).and_return(pod_set_success)
        subject.wait_until_completed
      end

      it { expect(subject.success?).to be(true) }
    end

    context "after wait_until_completed with a failing pod set" do
      before do
        allow(Vidar::K8s::PodSet).to receive(:new).and_return(pod_set_pending)
        subject.wait_until_completed
      end

      it { expect(subject.success?).to be(false) }
    end

    context "after wait_until_up only" do
      before do
        allow(Vidar::K8s::PodSet).to receive(:new).and_return(pod_set_success)
        subject.wait_until_up
      end

      it "reflects the last seen pod set" do
        expect(subject.success?).to be(true)
      end
    end
  end

  describe "namespace and filter are passed to PodSet" do
    subject { described_class.new(namespace: "production", filter: "web", max_tries: 1) }

    before do
      allow(Vidar::K8s::PodSet).to receive(:new)
        .with(namespace: "production", filter: "web")
        .and_return(pod_set_success)
      allow(subject).to receive(:sleep)
    end

    it "passes namespace and filter to K8s::PodSet" do
      expect(Vidar::K8s::PodSet).to receive(:new).with(namespace: "production", filter: "web")
      subject.wait_until_completed
    end
  end

  describe "default max_tries" do
    it "defaults to MAX_TRIES" do
      status = described_class.new(namespace: "staging")
      expect(status.max_tries).to eq(Vidar::DeployStatus::MAX_TRIES)
    end
  end
end

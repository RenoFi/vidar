RSpec.describe Vidar::K8s::PodSet do
  subject { described_class.new(namespace: "staging") }

  let(:running_pod_json) do
    {
      "items" => [
        {
          "metadata" => {"name" => "web-abc123", "namespace" => "staging", "ownerReferences" => []},
          "status" => {
            "containerStatuses" => [
              {
                "name" => "web",
                "ready" => true,
                "state" => {"running" => {"startedAt" => "2024-01-01T00:00:00Z"}}
              }
            ]
          }
        }
      ]
    }.to_json
  end

  let(:waiting_pod_json) do
    {
      "items" => [
        {
          "metadata" => {"name" => "web-abc123", "namespace" => "staging", "ownerReferences" => []},
          "status" => {
            "containerStatuses" => [
              {
                "name" => "web",
                "ready" => false,
                "state" => {"waiting" => {"reason" => "ContainerCreating"}}
              }
            ]
          }
        }
      ]
    }.to_json
  end

  describe "with running pods" do
    before { allow(subject).to receive(:kubectl_get).and_return(running_pod_json) }

    it { expect(subject.any?).to be(true) }
    it { expect(subject.deployed?).to be(true) }
    it { expect(subject.waiting?).to be(false) }
    it { expect(subject.success?).to be(true) }
  end

  describe "with waiting pods" do
    before { allow(subject).to receive(:kubectl_get).and_return(waiting_pod_json) }

    it { expect(subject.any?).to be(true) }
    it { expect(subject.deployed?).to be(false) }
    it { expect(subject.waiting?).to be(true) }
  end

  describe "when kubectl returns empty string" do
    before { allow(subject).to receive(:kubectl_get).and_return("") }

    it { expect(subject.any?).to be(false) }
    it { expect(subject.deployed?).to be(false) }
    it { expect(subject.success?).to be(false) }
  end

  describe "when kubectl returns invalid JSON" do
    before { allow(subject).to receive(:kubectl_get).and_return("Error from server: context deadline exceeded") }

    it "does not raise" do
      expect { subject.deployed? }.not_to raise_error
    end

    it { expect(subject.deployed?).to be(false) }
    it { expect(subject.any?).to be(false) }
  end

  describe "#containers with filter" do
    subject { described_class.new(namespace: "staging", filter: "web") }

    before { allow(subject).to receive(:kubectl_get).and_return(running_pod_json) }

    it "includes containers matching the filter" do
      expect(subject.containers.map(&:name)).to include("web")
    end
  end

  describe "#containers without filter" do
    before { allow(subject).to receive(:kubectl_get).and_return(running_pod_json) }

    it "excludes job containers" do
      expect(subject.containers).not_to be_empty
      subject.containers.each do |c|
        expect(c.job?).to be(false)
      end
    end
  end

  describe "with job pods" do
    let(:job_pod_json) do
      {
        "items" => [
          {
            "metadata" => {
              "name" => "deploy-hook-xyz",
              "namespace" => "staging",
              "ownerReferences" => [{"kind" => "Job"}]
            },
            "status" => {
              "containerStatuses" => [
                {
                  "name" => "deploy-hook",
                  "ready" => false,
                  "state" => {"terminated" => {"reason" => "Completed", "exitCode" => 0}}
                }
              ]
            }
          }
        ]
      }.to_json
    end

    subject { described_class.new(namespace: "staging", filter: "deploy-hook") }

    before { allow(subject).to receive(:kubectl_get).and_return(job_pod_json) }

    it { expect(subject.any?).to be(true) }
    it { expect(subject.deployed?).to be(true) }
    it { expect(subject.success?).to be(true) }
    it { expect(subject.waiting?).to be(false) }
  end

  describe "with all namespaces" do
    subject { described_class.new(namespace: "all") }

    let(:multi_ns_json) do
      {
        "items" => [
          {
            "metadata" => {"name" => "web-abc", "namespace" => "production", "ownerReferences" => []},
            "status" => {
              "containerStatuses" => [
                {"name" => "web", "ready" => true, "state" => {"running" => {"startedAt" => "2024-01-01T00:00:00Z"}}}
              ]
            }
          }
        ]
      }.to_json
    end

    before { allow(subject).to receive(:kubectl_get).and_return(multi_ns_json) }

    it { expect(subject.any?).to be(true) }
    it "preserves the namespace from pod metadata" do
      expect(subject.containers.first.namespace).to eq("production")
    end
  end

  describe "#success? with empty containers" do
    before { allow(subject).to receive(:kubectl_get).and_return({"items" => []}.to_json) }

    it { expect(subject.success?).to be(false) }
  end
end

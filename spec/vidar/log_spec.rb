RSpec.describe Vidar::Log do
  describe ".info" do
    it "outputs to stdout" do
      expect { described_class.info("hello") }.to output(/hello/).to_stdout
    end

    it "uses a custom fill character" do
      expect { described_class.info("msg", "-") }.to output(/-/).to_stdout
    end
  end

  describe ".error" do
    it "outputs to stdout" do
      expect { described_class.error("something went wrong") }.to output(/something went wrong/).to_stdout
    end
  end

  describe ".line" do
    it "outputs a separator line" do
      expect { described_class.line }.to output(/\|-+\|/).to_stdout
    end
  end
end

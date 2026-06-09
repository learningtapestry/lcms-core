# frozen_string_literal: true

require "rails_helper"

describe PrincePdf::Executable do
  before { described_class.reset! }
  after  { described_class.reset! }

  let(:success_status) { instance_double(Process::Status, success?: true) }
  let(:failure_status) { instance_double(Process::Status, success?: false) }

  describe ".path" do
    it "defaults to 'prince' when env unset" do
      original = ENV["PRINCE_EXECUTABLE_PATH"]
      ENV.delete("PRINCE_EXECUTABLE_PATH")
      expect(described_class.path).to eq("prince")
    ensure
      ENV["PRINCE_EXECUTABLE_PATH"] = original
    end

    it "honors PRINCE_EXECUTABLE_PATH env" do
      original = ENV["PRINCE_EXECUTABLE_PATH"]
      ENV["PRINCE_EXECUTABLE_PATH"] = "/opt/prince/bin/prince"
      expect(described_class.path).to eq("/opt/prince/bin/prince")
    ensure
      ENV["PRINCE_EXECUTABLE_PATH"] = original
    end
  end

  describe ".present?" do
    it "returns true when prince --version exits 0" do
      allow(Open3).to receive(:capture3).with(described_class.path, "--version")
                                        .and_return(["Prince 16.1\n", "", success_status])
      expect(described_class.present?).to be true
    end

    it "returns false when prince --version exits non-zero" do
      allow(Open3).to receive(:capture3).with(described_class.path, "--version")
                                        .and_return(["", "boom", failure_status])
      expect(described_class.present?).to be false
    end

    it "returns false when binary is missing (Errno::ENOENT)" do
      allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT)
      expect(described_class.present?).to be false
    end

    it "caches the result across calls" do
      allow(Open3).to receive(:capture3).and_return(["Prince 16.1\n", "", success_status])
      described_class.present?
      described_class.present?
      expect(Open3).to have_received(:capture3).once
    end
  end

  describe ".run" do
    it "invokes prince with stdin and returns stdout on success" do
      allow(Open3).to receive(:capture3).with(described_class.path, "-", "--output=-",
                                              stdin_data: "<html/>")
                                        .and_return(["%PDF-1.4 fake", "", success_status])
      result = described_class.run(["-", "--output=-"], stdin: "<html/>")
      expect(result).to eq("%PDF-1.4 fake")
    end

    it "raises NonZeroExit with stderr on failure" do
      allow(Open3).to receive(:capture3).and_return(["", "prince: error: boom", failure_status])
      expect { described_class.run([], stdin: "") }
        .to raise_error(described_class::NonZeroExit, /boom/)
    end
  end

  describe ".version" do
    it "returns the first line of stdout when prince exits 0" do
      allow(Open3).to receive(:capture3).with(described_class.path, "--version")
                                        .and_return(["Prince 16.1\nbuild info", "", success_status])
      expect(described_class.version).to eq("Prince 16.1")
    end

    it "returns nil on failure" do
      allow(Open3).to receive(:capture3).and_return(["", "boom", failure_status])
      expect(described_class.version).to be_nil
    end

    it "returns nil when binary missing" do
      allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT)
      expect(described_class.version).to be_nil
    end
  end
end

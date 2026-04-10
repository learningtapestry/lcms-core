# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Objects::Base do
  describe ".split_field" do
    let(:content) { parts.join separator }
    let(:parts) { %w(a b c d e) }
    let(:separator) { "-" }

    subject { described_class.split_field content, separator }

    it "returns splitted string" do
      expect(subject).to eq parts
    end
  end

  describe ".build_from" do
    it "builds from a hash with string keys" do
      obj = described_class.build_from("Subject" => "ela")
      expect(obj.subject).to eq "ela"
    end

    it "deep-transforms keys to underscore downcase" do
      obj = described_class.build_from("SUBJECT" => "ela")
      expect(obj.subject).to eq "ela"
    end

    it "sets default subject when key is missing" do
      obj = described_class.build_from({})
      expect(obj.subject).to eq SUBJECT_DEFAULT
    end
  end

  describe "hash-style access" do
    subject { described_class.new(subject: "ela") }

    it "reads attributes via []" do
      expect(subject[:subject]).to eq "ela"
    end

    it "writes attributes via []=" do
      subject[:subject] = "math"
      expect(subject.subject).to eq "math"
    end

    it "raises for unknown keys" do
      expect { subject[:nonexistent] }.to raise_error(NoMethodError)
    end
  end

  describe "#as_json" do
    subject { described_class.build_from("Subject" => "ela") }

    it "returns a hash containing all attributes" do
      json = subject.as_json
      expect(json).to be_a(Hash)
      expect(json["subject"]).to eq "ela"
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

describe ResourceStandardsLinkService do
  def lesson(standards, subject: "math", lesson: "1")
    create(:document, metadata: { "subject" => subject, "grade" => "2", "unit-id" => "u1", "section-number" => "1",
                                  "lesson-number" => lesson, "standards" => standards })
  end

  let!(:rl) { create(:standard, name: "RL.2.2", subject: "math") }
  let!(:w) { create(:standard, name: "W.2.1", subject: "math") }

  describe ".call" do
    it "links the resource to the standards its lesson lists, skipping unknown codes" do
      resource = lesson("rl.2.2; W.2.1,\nUNKNOWN.1, RL.2.2").resource

      expect(described_class.call(resource)).to eq %w(UNKNOWN.1)
      expect(resource.reload.standards).to contain_exactly(rl, w)
    end

    it "replaces earlier links" do
      resource = lesson("RL.2.2").resource
      resource.standards << w

      described_class.call(resource)

      expect(resource.reload.standards).to contain_exactly(rl)
    end

    it "prefers the lesson's subject when a code exists in two subjects" do
      science = create(:standard, name: "RL.2.2", subject: "science")
      resource = lesson("RL.2.2", subject: "science").resource

      described_class.call(resource)

      expect(resource.reload.standards).to contain_exactly(science)
    end

    it "does nothing for a resource without a lesson" do
      expect(described_class.call(create(:resource))).to be_nil
      expect(described_class.call(nil)).to be_nil
    end

    it "reads the codes from the configured metadata fields" do
      stub_const("#{described_class}::METADATA_FIELDS", %w(building-towards))
      document = lesson("W.2.1")
      document.update!(metadata: document.metadata.merge("building-towards" => "RL.2.2"))

      described_class.call(document.resource)

      expect(document.resource.reload.standards).to contain_exactly(rl)
    end
  end

  describe ".call_all" do
    it "re-links every resource with an active lesson" do
      first = lesson("RL.2.2", lesson: "1").resource
      second = lesson("W.2.1", lesson: "2").resource

      expect(described_class.call_all).to eq 2
      expect(first.reload.standards).to contain_exactly(rl)
      expect(second.reload.standards).to contain_exactly(w)
    end
  end
end

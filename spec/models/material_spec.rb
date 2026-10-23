# frozen_string_literal: true

require "rails_helper"

describe Material do
  it "has valid factory" do
    expect(create(:material)).to be_valid
  end

  let(:m_vocabulary_chart) { create(:material, metadata: { type: "vocabulary_chart" }) }
  let(:m_empty) { create(:material, metadata: {}) }

  subject { create :material }

  describe "validations" do
    it "has a file_id" do
      material = build :material, file_id: nil
      expect(material).to_not be_valid
    end
  end

  describe ".where_metadata" do
    before { m_vocabulary_chart }

    it { expect(Material.where_metadata(type: "vocabulary_chart").count).to eq 1 }
  end

  describe ".in_listed_order" do
    let!(:ack) { create(:material, identifier: "ack-1") }
    let!(:roster) { create(:material, identifier: "roster-1") }

    it "returns the listed materials in authored order, ignoring case, unknowns and repeats" do
      expect(described_class.in_listed_order("ROSTER-1, missing; ack-1\nroster-1")).to eq [roster, ack]
    end

    it "is empty for a blank row" do
      expect(described_class.in_listed_order(nil)).to eq []
    end
  end
end

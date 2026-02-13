# frozen_string_literal: true

require "rails_helper"

describe Material do
  it "has valid factory" do
    expect(create(:material)).to be_valid
  end

  let(:m_vocabulary_chart)  { create(:material, metadata: { type: "vocabulary_chart" }) }
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
end

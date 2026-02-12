# frozen_string_literal: true

require "rails_helper"

describe Material do
  it "has valid factory" do
    expect(create(:material)).to be_valid
  end

  let(:m_gdoc)  { create(:material, metadata: { type: "vocabulary_chart" }) }
  let(:m_empty) { create(:material, metadata: {}) }
  let(:m_pdf)   { create(:material, metadata: { type: "pdf" }) }

  subject { create :material }

  describe "validations" do
    it "has a file_id" do
      material = build :material, file_id: nil
      expect(material).to_not be_valid
    end
  end

  describe ".where_metadata" do
    before { m_gdoc }

    it { expect(Material.where_metadata(type: "vocabulary_chart").count).to eq 1 }
  end

  describe "source_type scopes" do
    before do
      m_gdoc
      m_empty
      m_pdf
    end

    context ".pdf" do
      it "returns pdf material" do
        expect(Material.pdf).to contain_exactly(m_pdf)
      end
    end

    context ".gdoc" do
      it "returns gdoc materials" do
        expect(Material.gdoc).to contain_exactly(m_gdoc, m_empty)
      end
    end
  end
end

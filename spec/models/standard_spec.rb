# frozen_string_literal: true

require "rails_helper"

describe Standard do
  it "has valid factory" do
    obj = create :standard
    expect(obj).to be_valid
  end

  # rubocop:disable Naming/VariableNumber
  describe "codes" do
    it "are unique within a subject regardless of case" do
      create(:standard, name: "RL.2.2", subject: "ela")

      expect(build(:standard, name: " rl.2.2 ", subject: "ELA")).not_to be_valid
      expect(build(:standard, name: "RL.2.2", subject: "math")).to be_valid
    end

    it "are normalized, with the subject lower-cased" do
      expect(build(:standard, name: "  RL.2.2 ", subject: " ELA ")).to have_attributes(name: "RL.2.2", subject: "ela")
    end
  end

  describe ".find_by_code" do
    let!(:rl) { create(:standard, name: "RL.2.2", subject: "ela", description: "Recount") }

    before { create(:standard, name: "RL.2.2a", subject: "ela") }

    it "matches the exact code, ignoring case and spacing, not codes that merely contain it" do
      expect(described_class.find_by_code(" rl.2.2 ")).to eq rl
      expect(described_class.find_by_code("RL.2")).to be_nil
    end

    it "matches an alt name, but prefers a code match" do
      by_alt = create(:standard, name: "CCSS.RL.2.2", subject: "ela", alt_names: %w(RL-2-2))
      create(:standard, name: "X.1", subject: "ela", alt_names: %w(RL.2.2))

      expect(described_class.find_by_code("rl-2-2")).to eq by_alt
      expect(described_class.find_by_code("RL.2.2")).to eq rl
    end

    it "prefers a standard in the given subject" do
      math = create(:standard, name: "RL.2.2", subject: "math")

      expect(described_class.find_by_code("RL.2.2", subject: "Math")).to eq math
      expect(described_class.find_by_code("RL.2.2", subject: "ela")).to eq rl
    end

    it "falls back to the code without a subject prefix" do
      expect(described_class.find_by_code("ELA.RL.2.2")).to eq rl
      expect(described_class.find_by_code("Math.RL.2.2")).to eq rl
    end

    it { expect(described_class.find_by_code("")).to be_nil }
  end

  describe ".search_by_name" do
    let(:alt_name) { "a-synonym" }
    let(:name) { "test-std" }
    let(:standard_1) { create :standard, alt_names: [alt_name.upcase], grades: ["grade 10"], subject: "ela" }
    let(:standard_2) { create :standard, alt_names: %w(fake), grades: ["grade 10"], name: name.upcase, subject: "ela" }

    it { expect(described_class.search_by_name("qwerty").first).to be_nil }

    it "searches by alt_name" do
      standard_1
      expect(described_class.search_by_name(alt_name).first).to eq standard_1
    end

    it "searches by name" do
      standard_2
      expect(described_class.search_by_name(name).first).to eq standard_2
    end
  end
  # rubocop:enable Naming/VariableNumber
end

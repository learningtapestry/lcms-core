# frozen_string_literal: true

require "rails_helper"

RSpec.describe Setting, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:key) }
  end

  describe "after_commit" do
    it "invalidates the Settings cache for the affected key" do
      record = described_class.new(key: "appearance", value: { foo: "bar" })

      expect(Settings).to receive(:expire_cache_for).with("appearance")
      record.save!
    end

    it "invalidates the Settings cache after destroy" do
      record = described_class.create!(key: "appearance", value: { foo: "bar" })

      expect(Settings).to receive(:expire_cache_for).with("appearance")
      record.destroy
    end
  end
end

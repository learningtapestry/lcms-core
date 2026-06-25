# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::AdminController do
  describe "#admin_layout" do
    subject(:layout) { described_class.new.send(:admin_layout) }

    it "defaults to the shipped admin layout" do
      expect(layout).to eq("admin")
    end

    it "is overridable through the :admin setting" do
      Settings.set(:admin, "layout" => "fork_admin")

      expect(layout).to eq("fork_admin")
    end
  end
end

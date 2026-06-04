# frozen_string_literal: true

require "rails_helper"

RSpec.describe SettingsForm do
  before { Rails.cache.clear }

  def form(attrs)
    described_class.new(ActionController::Parameters.new(attrs))
  end

  describe "#save" do
    it "persists a flat-group change and returns true" do
      expect(form(header_bg_color: "#abcdef").save).to be(true)
      expect(Settings.get(:appearance)["header_bg_color"]).to eq("#abcdef")
    end

    it "does not persist a value equal to the current default" do
      default = Settings::DEFAULTS[:appearance][:header_bg_color]

      expect(form(header_bg_color: default).save).to be(true)
      expect(Setting.find_by(key: "appearance")).to be_nil
    end

    it "persists a form-group change (casting the textarea to a list)" do
      expect(form(admin_view_links: { documents: "/x/:id\n/y/:id" }).save).to be(true)
      expect(Settings.get(:admin_view_links)["documents"]).to eq(["/x/:id", "/y/:id"])
    end

    context "when a form group is invalid" do
      before { allow_any_instance_of(Setting::AdminViewLinks).to receive(:valid?).and_return(false) }

      it "returns false and rolls back earlier flat-group writes (atomic save)" do
        saved = form(header_bg_color: "#abcdef", admin_view_links: { documents: "/x/:id" }).save

        expect(saved).to be(false)
        expect(Setting.find_by(key: "appearance")).to be_nil
      end
    end
  end

  describe "groups" do
    it "exposes one group per SETTINGS entry, each rendered by its own partial" do
      by_key = form({}).groups.index_by(&:key)

      expect(by_key[:appearance]).to be_a(described_class::FlatGroup)
      expect(by_key[:appearance].to_partial_path).to eq("admin/settings/groups/flat")
      expect(by_key[:admin_view_links]).to be_a(described_class::FormGroup)
      expect(by_key[:admin_view_links].to_partial_path).to eq("admin/settings/groups/form")
    end

    it "a FlatGroup exposes its fields and current (defaults-merged) values" do
      group = described_class.group_for("header_bg_color")

      expect(group.fields).to eq(SETTINGS[:appearance])
      expect(group.value_for(:header_bg_color)).to eq(Settings::DEFAULTS[:appearance][:header_bg_color])
    end

    it "a FormGroup exposes its model for the view" do
      expect(described_class.group_for("admin_view_links").model).to be_a(Setting::AdminViewLinks)
    end
  end

  describe ".group_for" do
    it "maps a flat leaf key to its FlatGroup" do
      expect(described_class.group_for("header_bg_color")).to be_a(described_class::FlatGroup)
    end

    it "maps a form group key to its FormGroup" do
      expect(described_class.group_for("admin_view_links")).to be_a(described_class::FormGroup)
    end

    it "returns nil for an unknown key" do
      expect(described_class.group_for("nope")).to be_nil
    end
  end

  describe "group#reset" do
    it "FlatGroup#reset removes only the named leaf" do
      Settings.set(:appearance, { "header_bg_color" => "#ff0000", "header_text_color" => "#000000" })

      described_class.group_for("header_bg_color").reset("header_bg_color")

      expect(Settings.get(:appearance)).to eq("header_text_color" => "#000000")
    end

    it "FormGroup#reset restores the shipped defaults" do
      Settings.set(:admin_view_links, { "documents" => ["/changed"] })

      described_class.group_for("admin_view_links").reset("admin_view_links")

      expect(Settings.get(:admin_view_links)["documents"]).to eq(["/documents/:id"])
    end

    it "FormGroup#reset unsets the row when the group has no shipped defaults" do
      stub_const("Settings::DEFAULTS", Settings::DEFAULTS.except(:admin_view_links))
      Settings.set(:admin_view_links, { "documents" => ["/changed"] })

      described_class.group_for("admin_view_links").reset("admin_view_links")

      expect(Setting.find_by(key: "admin_view_links")).to be_nil
    end
  end
end

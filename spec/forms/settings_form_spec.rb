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

    # The submitted list/map values are string-keyed while the defaults come
    # back symbolized, so a naive == treats an unchanged list as a change and
    # pins the shipped defaults into the DB as an explicit override.
    it "does not persist a resubmitted list field equal to the shipped default" do
      defaults = Settings::DEFAULTS[:documents][:callout_types]
      submitted = defaults.map { |type| type.deep_stringify_keys }

      expect(form(callout_types_submitted: "1", callout_types: submitted).save).to be(true)
      expect(Setting.find_by(key: "documents")).to be_nil
    end

    it "persists a form-group change (casting the textarea to a list)" do
      expect(form(admin_view_links: { documents: "/x/:id\n/y/:id" }).save).to be(true)
      expect(Settings.get(:admin_view_links)["documents"]).to eq(["/x/:id", "/y/:id"])
    end

    context "when a form group is invalid" do
      before { allow_any_instance_of(Setting::AdminViewLinks).to receive(:valid?).and_return(false) }

      it "returns false and persists nothing (no partial write)" do
        saved = form(header_bg_color: "#abcdef", admin_view_links: { documents: "/x/:id" }).save

        expect(saved).to be(false)
        expect(Setting.find_by(key: "appearance")).to be_nil
      end
    end
  end

  describe "#save with a :key_value_list field" do
    it "persists submitted rows as an ordered abbr => label Hash" do
      expect(form(lesson_types_submitted: "1", lesson_types: [
        { abbr: "AP", label: "Anchoring Phenomenon" },
        { abbr: "CMB", label: "Class Model Building" }
      ]).save).to be(true)

      expect(Settings.get(:documents)["lesson_types"]).to eq(
        "AP" => "Anchoring Phenomenon",
        "CMB" => "Class Model Building"
      )
    end

    it "strips whitespace and drops rows with a blank abbreviation or label" do
      expect(form(lesson_types_submitted: "1", lesson_types: [
        { abbr: " AP ", label: " Anchoring Phenomenon " },
        { abbr: "  ", label: "Missing abbr" },
        { abbr: "NL", label: "  " }
      ]).save).to be(true)

      expect(Settings.get(:documents)["lesson_types"]).to eq("AP" => "Anchoring Phenomenon")
    end

    it "lets a later duplicate abbreviation overwrite an earlier one" do
      expect(form(lesson_types_submitted: "1", lesson_types: [
        { abbr: "AP", label: "First" },
        { abbr: "AP", label: "Second" }
      ]).save).to be(true)

      expect(Settings.get(:documents)["lesson_types"]).to eq("AP" => "Second")
    end

    it "collapses abbreviations that differ only in case (later row wins)" do
      expect(form(lesson_types_submitted: "1", lesson_types: [
        { abbr: "AP", label: "Anchoring Phenomenon" },
        { abbr: "ap", label: "Applied Practice" }
      ]).save).to be(true)

      expect(Settings.get(:documents)["lesson_types"]).to eq("ap" => "Applied Practice")
    end

    it "clears the map when the widget is submitted with no rows" do
      Settings.set(:documents, "lesson_types" => { "AP" => "Anchoring Phenomenon" })

      expect(form(lesson_types_submitted: "1").save).to be(true)

      expect(Settings.get(:documents)["lesson_types"]).to eq({})
    end

    it "leaves the stored map untouched when the field is omitted entirely" do
      Settings.set(:documents, "lesson_types" => { "AP" => "Anchoring Phenomenon" })

      expect(form(copyright_text: "unchanged").save).to be(true)

      expect(Settings.get(:documents)["lesson_types"]).to eq("AP" => "Anchoring Phenomenon")
    end
  end

  describe "#save with a :label_map field" do
    it "persists submitted labels as a key => label Hash" do
      expect(form(student_groupings: { "class" => "Whole Class", "small group" => "Small Groups" }).save).to be(true)

      expect(Settings.get(:documents)["student_groupings"]).to eq(
        "class" => "Whole Class",
        "small group" => "Small Groups"
      )
    end

    it "strips whitespace and drops blank labels, leaving unconfigured keys absent" do
      expect(form(student_groupings: { "class" => " Whole Class ", "individual" => "  " }).save).to be(true)

      expect(Settings.get(:documents)["student_groupings"]).to eq("class" => "Whole Class")
    end

    it "ignores a key outside the fixed GROUPING_OPTIONS vocabulary" do
      expect(form(student_groupings: { "class" => "Whole Class", "bogus" => "Nope" }).save).to be(true)

      expect(Settings.get(:documents)["student_groupings"]).to eq("class" => "Whole Class")
    end

    it "leaves the stored map untouched when the field is omitted entirely" do
      Settings.set(:documents, "student_groupings" => { "class" => "Whole Class" })

      expect(form(copyright_text: "unchanged").save).to be(true)

      expect(Settings.get(:documents)["student_groupings"]).to eq("class" => "Whole Class")
    end
  end

  describe "#save with a :callout_list field" do
    it "persists submitted rows as an ordered Array of type/title/image Hashes" do
      expect(form(callout_types_submitted: "1", callout_types: [
        { type: "tip", title: "Teaching Tip" },
        { type: "custom", title: "Custom Type" }
      ]).save).to be(true)

      expect(Settings.get(:documents)["callout_types"]).to eq(
        [
          { "type" => "tip", "title" => "Teaching Tip", "image" => nil },
          { "type" => "custom", "title" => "Custom Type", "image" => nil }
        ]
      )
    end

    it "uploads a new icon file for a row and stores its URL" do
      uploader = instance_double(ImageUploader, store!: true, url: "/uploads/settings/tip.png")
      allow(ImageUploader).to receive(:new).and_return(uploader)
      image_file = Tempfile.new(["tip_icon", ".png"]).tap do |f|
        f.binmode
        f.write("\x89PNG\r\n\x1a\n")
        f.rewind
      end
      uploaded_file = Rack::Test::UploadedFile.new(image_file.path, "image/png")

      expect(form(callout_types_submitted: "1", callout_types: [
        { type: "tip", title: "Teaching Tip", image: uploaded_file }
      ]).save).to be(true)

      expect(uploader).to have_received(:store!).with(uploaded_file)
      expect(Settings.get(:documents)["callout_types"]).to eq(
        [{ "type" => "tip", "title" => "Teaching Tip", "image" => "/uploads/settings/tip.png" }]
      )
    ensure
      image_file&.close!
    end

    it "keeps the existing icon (looked up by type) when no new file is uploaded" do
      Settings.set(:documents, "callout_types" => [
        { "type" => "tip", "title" => "Teaching Tip", "image" => "/uploads/settings/old.png" }
      ])

      expect(form(callout_types_submitted: "1", callout_types: [
        { type: "tip", title: "Renamed Tip" }
      ]).save).to be(true)

      expect(Settings.get(:documents)["callout_types"]).to eq(
        [{ "type" => "tip", "title" => "Renamed Tip", "image" => "/uploads/settings/old.png" }]
      )
    end

    it "never persists a client-supplied image URL string" do
      expect(form(callout_types_submitted: "1", callout_types: [
        { type: "tip", title: "Teaching Tip", image: "https://evil.example.com/x.png" }
      ]).save).to be(true)

      expect(Settings.get(:documents)["callout_types"]).to eq(
        [{ "type" => "tip", "title" => "Teaching Tip", "image" => nil }]
      )
    end

    it "downcases the type and drops rows with a blank type" do
      expect(form(callout_types_submitted: "1", callout_types: [
        { type: " TIP ", title: " Teaching Tip " },
        { type: "  ", title: "Missing type" }
      ]).save).to be(true)

      expect(Settings.get(:documents)["callout_types"]).to eq(
        [{ "type" => "tip", "title" => "Teaching Tip", "image" => nil }]
      )
    end

    it "lets a later duplicate type overwrite an earlier one" do
      expect(form(callout_types_submitted: "1", callout_types: [
        { type: "tip", title: "First" },
        { type: "tip", title: "Second" }
      ]).save).to be(true)

      expect(Settings.get(:documents)["callout_types"]).to eq(
        [{ "type" => "tip", "title" => "Second", "image" => nil }]
      )
    end

    it "clears the list when the widget is submitted with no rows" do
      Settings.set(:documents, "callout_types" => [{ "type" => "tip", "title" => "Teaching Tip" }])

      expect(form(callout_types_submitted: "1").save).to be(true)

      expect(Settings.get(:documents)["callout_types"]).to eq([])
    end

    it "leaves the stored list untouched when the field is omitted entirely" do
      Settings.set(:documents, "callout_types" => [{ "type" => "tip", "title" => "Teaching Tip" }])

      expect(form(copyright_text: "unchanged").save).to be(true)

      expect(Settings.get(:documents)["callout_types"]).to eq([{ "type" => "tip", "title" => "Teaching Tip" }])
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

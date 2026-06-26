# frozen_string_literal: true

require "rails_helper"

RSpec.describe ContentPresenter do
  before { Rails.cache.clear }

  describe ".base_config" do
    it "reads the :pdf setting merged with shipped defaults" do
      Setting.create!(key: :pdf, value: { "default" => { "orientation" => "landscape" } })

      config = described_class.base_config

      expect(config[:default][:orientation]).to eq("landscape")
      # untouched keys still come from the defaults
      expect(config[:default][:dpi]).to eq(Settings::DEFAULTS[:pdf][:default][:dpi])
      expect(config[:handout][:name_date]).to be(true)
    end

    it "returns the shipped defaults when no override is stored" do
      expect(described_class.base_config).to eq(Settings::DEFAULTS[:pdf])
    end

    it "falls back to defaults when the database is unavailable" do
      allow(Settings).to receive(:get)
        .with(:pdf, include_defaults: true)
        .and_raise(ActiveRecord::NoDatabaseError)

      expect(described_class.base_config).to eq(Settings::DEFAULTS[:pdf])
    end
  end

  describe "#config" do
    it "deep-merges the content-type block on top of :default" do
      presenter = described_class.new(Object.new, content_type: "handout")

      defaults = Settings::DEFAULTS[:pdf]
      # inherited from :default
      expect(presenter.config[:dpi]).to eq(defaults[:default][:dpi])
      expect(presenter.config[:orientation]).to eq("portrait")
      # overridden by :handout
      expect(presenter.config[:name_date]).to be(true)
      expect(presenter.config[:margin][:top]).to eq("1.25in")
    end

    it "returns just the :default block for an unknown content type" do
      presenter = described_class.new(Object.new, content_type: "full")

      expect(presenter.config).to eq(Settings::DEFAULTS[:pdf][:default])
    end

    it "does not crash when content_type names a non-geometry key" do
      # Regression: default_renderer used to be a top-level String sibling of the
      # content-type blocks under :pdf, so content_type=default_renderer (from
      # params[:type]) made base[content_type] a String and deep_merge raised.
      # Renderer choice now lives in :pdf_renderer, so :pdf holds only blocks.
      Settings.set(:pdf_renderer, "default_renderer" => "prince")
      presenter = described_class.new(Object.new, content_type: "default_renderer")

      expect { presenter.config }.not_to raise_error
      expect(presenter.config).to eq(Settings::DEFAULTS[:pdf][:default])
    end
  end

  describe "#orientation and padding helpers" do
    # These resolve through render_options, which builds a filename from the
    # wrapped record's breadcrumb, so the record must answer short_breadcrumb.
    let(:record) { double("record", short_breadcrumb: "lesson", version: 1) }
    let(:presenter) { described_class.new(record, content_type: "default") }

    it "exposes orientation from the resolved config" do
      expect(presenter.orientation).to eq(:portrait)
    end

    it "builds padding and footer-margin CSS from the resolved config" do
      expect(presenter.padding_styles).to eq("padding-right:0;padding-left:0;")
      expect(presenter.footer_margin_styles).to eq("margin-right:0;margin-left:0;")
    end
  end
end

# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/migrate/20261120130000_remove_stored_pdf_geometry")

RSpec.describe RemoveStoredPdfGeometry do
  before { Rails.cache.clear }

  def migrate
    described_class.new.tap { |m| m.verbose = false }.up
  end

  it "removes the stored :pdf row so the code defaults apply" do
    Settings.set(:pdf, "default" => { "dpi" => 999, "margin" => { "right" => "1in" } })

    migrate

    expect(Setting.find_by(key: "pdf")).to be_nil
    expect(Settings.get(:pdf, include_defaults: true)).to eq(Settings::DEFAULTS[:pdf])
  end

  it "leaves other settings alone" do
    Settings.set(:pdf_renderer, "default_renderer" => "grover")

    migrate

    expect(Settings.get(:pdf_renderer)).to eq("default_renderer" => "grover")
  end

  it "is a no-op when nothing is stored" do
    expect { migrate }.not_to raise_error
  end
end

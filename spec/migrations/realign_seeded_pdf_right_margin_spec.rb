# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/migrate/20260810000000_realign_seeded_pdf_right_margin")

RSpec.describe RealignSeededPdfRightMargin do
  before { Rails.cache.clear }

  def migrate
    described_class.new.tap { |m| m.verbose = false }.up
  end

  def stored_right_margin
    Settings.get(:pdf).dig("default", "margin", "right")
  end

  def seed(right)
    Settings.set(:pdf, "default" => { "margin" => { "top" => "0.5in", "right" => right } })
  end

  it "rewrites a stored right margin still equal to the old shipped default" do
    seed("1in")

    migrate

    expect(stored_right_margin).to eq("0.5in")
  end

  it "leaves the rest of the stored :pdf settings untouched" do
    seed("1in")

    migrate

    expect(Settings.get(:pdf).dig("default", "margin", "top")).to eq("0.5in")
  end

  it "leaves an operator-chosen margin alone" do
    seed("1.25in")

    migrate

    expect(stored_right_margin).to eq("1.25in")
  end

  it "is a no-op when nothing is stored for :pdf" do
    expect { migrate }.not_to raise_error
    expect(Settings.get(:pdf)).to be_nil
  end

  it "is idempotent" do
    seed("1in")

    migrate
    migrate

    expect(stored_right_margin).to eq("0.5in")
  end
end

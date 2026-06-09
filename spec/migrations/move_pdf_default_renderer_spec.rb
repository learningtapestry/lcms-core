# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/migrate/20260606000000_move_pdf_default_renderer")

RSpec.describe MovePdfDefaultRenderer do
  before { Rails.cache.clear }

  def migrate
    described_class.new.tap { |m| m.verbose = false }.up
  end

  it "moves default_renderer out of :pdf into :pdf_renderer and strips the stale key" do
    Settings.set(:pdf, "default" => { "dpi" => 72 }, "default_renderer" => "prince")

    migrate

    expect(Settings.get(:pdf)).to eq("default" => { "dpi" => 72 })
    expect(Settings.get(:pdf_renderer)).to eq("default_renderer" => "prince")
  end

  it "keeps an explicitly-configured :pdf_renderer instead of clobbering it" do
    Settings.set(:pdf, "default" => { "dpi" => 72 }, "default_renderer" => "prince")
    Settings.set(:pdf_renderer, "default_renderer" => "grover")

    migrate

    expect(Settings.get(:pdf)).not_to have_key("default_renderer")
    expect(Settings.get(:pdf_renderer)).to eq("default_renderer" => "grover")
  end

  it "is a no-op when :pdf carries no default_renderer" do
    Settings.set(:pdf, "default" => { "dpi" => 72 })

    migrate

    expect(Settings.get(:pdf_renderer)).to be_nil
    expect(Settings.get(:pdf)).to eq("default" => { "dpi" => 72 })
  end
end

# frozen_string_literal: true

require "rails_helper"

describe DocTemplate, ".config" do
  before { described_class.reload! }
  after { described_class.reload! }

  it "reads the doc_template setting through Settings" do
    allow(Settings).to receive(:get)
      .with(:doc_template, include_defaults: true)
      .and_return(sanitizer: "HtmlSanitizer")

    expect(described_class.config).to eq(sanitizer: "HtmlSanitizer")
  end

  context "when the database is briefly unavailable on the first read" do
    def settings_failing_once(recovered)
      calls = 0
      allow(Settings).to receive(:get)
        .with(:doc_template, include_defaults: true) do
          calls += 1
          raise ActiveRecord::ConnectionNotEstablished if calls == 1

          recovered
        end
    end

    it "serves defaults without pinning them, then picks up the real config once the DB recovers" do
      settings_failing_once(sanitizer: "String")

      # First access during the outage falls back to the shipped defaults...
      expect(described_class.config).to eq(Settings::DEFAULTS[:doc_template])
      # ...but the fallback is not memoized, so the next call retries the DB.
      expect(described_class.config).to eq(sanitizer: "String")
    end

    it "does not pin a derived accessor to the fallback" do
      settings_failing_once(sanitizer: "String")

      # Defaults during the outage (the shipped sanitizer class)...
      expect(described_class.sanitizer).to eq(HtmlSanitizer)
      # ...then the recovered value, proving it was not memoized to the default.
      expect(described_class.sanitizer).to eq(String)
    end
  end
end

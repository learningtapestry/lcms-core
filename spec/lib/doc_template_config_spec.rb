# frozen_string_literal: true

require "rails_helper"

describe DocTemplate, ".config" do
  # reload! clears the per-request memo, standing in for "the next request/job".
  before { described_class.reload! }
  after { described_class.reload! }

  it "reads the doc_template setting through Settings" do
    allow(Settings).to receive(:get)
      .with(:doc_template, include_defaults: true)
      .and_return(sanitizer: "HtmlSanitizer")

    expect(described_class.config).to eq(sanitizer: "HtmlSanitizer")
  end

  it "applies a changed setting on the next request without a restart" do
    allow(Settings).to receive(:get)
      .with(:doc_template, include_defaults: true)
      .and_return({ sanitizer: "HtmlSanitizer" }, { sanitizer: "String" })

    # Stable within a unit of work (memoized, so hot loops stay cheap)...
    expect(described_class.sanitizer).to eq(HtmlSanitizer)
    expect(described_class.sanitizer).to eq(HtmlSanitizer)

    described_class.reload! # next request/job: Current is reset

    expect(described_class.sanitizer).to eq(String)
  end

  context "when the database is briefly unavailable" do
    def settings_failing_once(recovered)
      calls = 0
      allow(Settings).to receive(:get)
        .with(:doc_template, include_defaults: true) do
          calls += 1
          raise ActiveRecord::ConnectionNotEstablished if calls == 1

          recovered
        end
    end

    it "serves defaults during the outage, then recovers on the next request" do
      settings_failing_once(sanitizer: "String")

      # During the outage the request falls back to the shipped defaults...
      expect(described_class.config).to eq(Settings::DEFAULTS[:doc_template])

      described_class.reload! # next request retries the DB

      expect(described_class.config).to eq(sanitizer: "String")
    end

    it "never pins the fallback into a derived accessor beyond the request" do
      settings_failing_once(sanitizer: "String")

      expect(described_class.sanitizer).to eq(HtmlSanitizer) # default during outage

      described_class.reload!

      expect(described_class.sanitizer).to eq(String) # recovered next request
    end
  end
end

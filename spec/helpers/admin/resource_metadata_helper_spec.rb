# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::ResourceMetadataHelper, type: :helper do
  describe "#resource_metadata_value" do
    it "leaves plain strings unsafe so the view escapes them" do
      value = helper.resource_metadata_value("Tom & Jerry")

      expect(value).to eq("Tom & Jerry")
      expect(value).not_to be_html_safe
    end

    it "keeps text formatting in authored HTML" do
      html = helper.resource_metadata_value(%(<p>Read <strong>this</strong> <a href="https://x.test">link</a></p>))

      expect(html).to eq(%(<p>Read <strong>this</strong> <a href="https://x.test">link</a></p>))
    end

    it "drops tags that load remote resources or run script" do
      html = helper.resource_metadata_value(
        %(<p>Hi</p><img src="https://tracker.test/x.png"><iframe src="https://x.test"></iframe><script>alert(1)</script>)
      )

      expect(html).to include("<p>Hi</p>")
      expect(html).not_to include("<img", "<iframe", "<script")
    end

    it "does not mistake plain-text comparisons for markup" do
      ["a <b and c> d", "x<y and y>z"].each do |text|
        value = helper.resource_metadata_value(text)

        expect(value).to eq(text)
        expect(value).not_to be_html_safe
      end
    end

    it "renders each array item like a single value" do
      html = helper.resource_metadata_value(["<b>One</b>", "a & b", { "k" => 1 }])

      expect(html).to include("<b>One</b>", "a &amp; b", "<pre")
      expect(html).not_to include("=&gt;")
    end

    it "renders hashes as pretty JSON" do
      expect(helper.resource_metadata_value({ "k" => 1 })).to include("<pre", "&quot;k&quot;: 1")
    end
  end
end

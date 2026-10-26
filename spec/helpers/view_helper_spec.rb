# frozen_string_literal: true

require "rails_helper"

describe ViewHelper do
  describe "#render_tags" do
    before { create(:link, identifier: "nasa-01", url: "https://www.nasa.gov/", text: "NASA") }

    it "renders the tags in a metadata field as safe HTML" do
      result = helper.render_tags("<p><span>See [url: nasa-01]</span></p>", :gdoc)

      expect(result).to eq %(<p><span>See <a href="https://www.nasa.gov/">NASA</a></span></p>)
      expect(result).to be_html_safe
    end
  end
end

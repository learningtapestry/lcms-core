# frozen_string_literal: true

require "rails_helper"

describe Link do
  it "stores the identifier downcased and finds it case-insensitively" do
    link = create(:link, identifier: " NASA-01 ")

    expect(link.identifier).to eq "nasa-01"
    expect(described_class.find_by_identifier("Nasa-01 ")).to eq link
  end

  it "accepts only http(s) URLs" do
    expect(build(:link, url: "javascript:alert(1)")).not_to be_valid
  end

  it "labels the link with its text, else its URL" do
    expect(build(:link, url: "https://nasa.gov", text: "NASA").label).to eq "NASA"
    expect(build(:link, url: "https://nasa.gov", text: "").label).to eq "https://nasa.gov"
  end
end

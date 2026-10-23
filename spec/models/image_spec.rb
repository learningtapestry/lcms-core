# frozen_string_literal: true

require "rails_helper"

describe Image do
  it "stores the identifier downcased and finds it case-insensitively" do
    image = create(:image, identifier: " 1234BW20P ")

    expect(image.identifier).to eq "1234bw20p"
    expect(described_class.find_by_identifier("1234Bw20p ")).to eq image
  end

  it "accepts only http(s) file URLs" do
    expect(build(:image, file_url: "javascript:alert(1)")).not_to be_valid
  end
end

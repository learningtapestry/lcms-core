# frozen_string_literal: true

require "rails_helper"

describe "admin/materials/_search_form", type: :view do
  it "renders material_type as a free-text field" do
    render partial: "admin/materials/search_form"

    expect(rendered).to include('name="query[material_type]"')
    expect(rendered).to include('placeholder="Enter Material Type"')
    expect(rendered).not_to include('<select name="query[material_type]"')
  end
end

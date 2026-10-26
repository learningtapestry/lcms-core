# frozen_string_literal: true

require "rails_helper"

describe "units/gdoc/_acknowledgements", type: :view do
  let(:metadata) { { "acknowledgements" => acknowledgements } }
  let(:unit) { UnitPresenter.new(Resource.new(metadata: metadata)) }

  context "when the unit has acknowledgements" do
    let(:acknowledgements) do
      "<h3>Steering Committee</h3><p>Name Name, Organization</p>"
    end

    it "renders the injected Acknowledgements heading" do
      render partial: "units/gdoc/acknowledgements", locals: { unit: }
      expect(rendered).to have_css("h1 span.o-gdoc-h1", text: "Acknowledgements")
    end

    it "renders the authored sub-sections and names verbatim" do
      render partial: "units/gdoc/acknowledgements", locals: { unit: }
      expect(rendered).to include("<h3>Steering Committee</h3>")
      expect(rendered).to include("Name Name, Organization")
    end
  end

  context "when the unit has no acknowledgements" do
    let(:acknowledgements) { "" }

    it "renders nothing" do
      render partial: "units/gdoc/acknowledgements", locals: { unit: }
      expect(rendered.strip).to be_blank
    end
  end
end

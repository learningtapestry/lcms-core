# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Template do
  let(:html_document) do
    <<-HTML
      <html>
        <head></head>
        <body>
          <table><tr><td>#{DocTemplate::Tables::Document::HEADER_LABEL}</td></tr></table>
          #{content}
        </body>
      </html>
    HTML
  end

  describe "tag rendering" do
    describe "unknown tags render error" do
      let(:tag) { "<span>[ATAG: </span><span>ending]</span>" }
      let(:content) { "<p><span>stay</span>#{tag}</p><p>info to slice</p>" }

      subject { DocTemplate::Template.parse(html_document).render }

      it "keeps surrounding content" do
        expect(subject).to include("stay")
      end

      it "renders a badge for the unknown tag" do
        expect(subject).to include("badge text-bg-danger")
        expect(subject).to include("Unknown tag: ATAG")
      end
    end
  end
end

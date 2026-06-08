# frozen_string_literal: true

require "rails_helper"

describe HasGdocSource do
  let(:klass) do
    Class.new do
      include HasGdocSource

      attr_reader :links

      def initialize(links)
        @links = links
      end
    end
  end

  let(:links) do
    {
      "source" => {
        "gdoc" => {
          "name" => "Lesson 1 Source",
          "url" => "https://docs.google.com/document/d/abc123"
        }
      }
    }
  end

  subject(:presenter) { klass.new(links) }

  describe "#source_name" do
    it "returns the name from the gdoc source link" do
      expect(presenter.source_name).to eq("Lesson 1 Source")
    end

    context "when the gdoc source is missing" do
      let(:links) { { "source" => {} } }

      it "returns nil" do
        expect(presenter.source_name).to be_nil
      end
    end

    context "when links are empty" do
      let(:links) { {} }

      it "returns nil" do
        expect(presenter.source_name).to be_nil
      end
    end
  end

  describe "#source_url" do
    it "returns the URL from the gdoc source link" do
      expect(presenter.source_url).to eq("https://docs.google.com/document/d/abc123")
    end

    context "when the gdoc source is missing" do
      let(:links) { { "source" => {} } }

      it "returns nil" do
        expect(presenter.source_url).to be_nil
      end
    end

    context "when links are empty" do
      let(:links) { {} }

      it "returns nil" do
        expect(presenter.source_url).to be_nil
      end
    end
  end
end

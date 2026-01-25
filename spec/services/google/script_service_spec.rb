# frozen_string_literal: true

require "rails_helper"

describe Google::ScriptService do
  let(:document) do
    double(
      "DocumentPresenter",
      orientation: "portrait",
      gdoc_footer: [["{attribution}"], ["CC BY-NC-SA"]],
      gdoc_header: [["{title}"], ["Test Document"]]
    )
  end
  let(:service) { described_class.new(document) }

  describe "#execute" do
    let(:script_service) { instance_double(::Google::Apis::ScriptV1::ScriptService) }
    let(:credentials) { double("Google::Auth::ServiceAccountCredentials") }
    let(:document_id) { "doc_123" }
    let(:response) { double("Response", error: nil, blank?: false) }

    before do
      allow(service).to receive(:google_credentials).and_return(credentials)
      allow(service).to receive(:service).and_return(script_service)
      allow(script_service).to receive(:run_script).and_return(response)
      allow(ENV).to receive(:fetch).with("GOOGLE_APPLICATION_TEMPLATE_PORTRAIT").and_return("template_id")
    end

    it "creates an execution request and runs the script" do
      expect(script_service).to receive(:run_script)
        .with(described_class::SCRIPT_ID, instance_of(::Google::Apis::ScriptV1::ExecutionRequest))
        .and_return(response)

      service.execute(document_id)
    end

    context "when response is blank" do
      before do
        allow(script_service).to receive(:run_script).and_return(nil)
      end

      it "raises Google::Apis::Error" do
        expect { service.execute(document_id) }
          .to raise_error(::Google::Apis::Error, /Empty response from Google Apps Script/)
      end
    end

    context "when response has error" do
      let(:error_details) do
        [{ "errorMessage" => "Script error occurred" }]
      end
      let(:error) { double("Error", details: error_details) }
      let(:response) { double("Response", error: error, blank?: false) }

      it "raises Google::Apis::Error with error message" do
        expect { service.execute(document_id) }
          .to raise_error(::Google::Apis::Error, /Script error occurred/)
      end
    end

    context "when response has error with stack trace" do
      let(:error_details) do
        [{
          "errorMessage" => "Script error",
          "scriptStackTraceElements" => [
            { "function" => "processDocument", "lineNumber" => 42 }
          ]
        }]
      end
      let(:error) { double("Error", details: error_details) }
      let(:response) { double("Response", error: error, blank?: false) }

      it "includes stack trace in error message" do
        expect { service.execute(document_id) }
          .to raise_error(::Google::Apis::Error, /processDocument.*42/)
      end
    end
  end

  describe "private methods" do
    describe "#gdoc_template_id" do
      context "when document has portrait orientation" do
        let(:document) do
          double("DocumentPresenter", orientation: "portrait", gdoc_footer: [], gdoc_header: [])
        end

        it "returns portrait template ID from ENV" do
          allow(ENV).to receive(:fetch)
            .with("GOOGLE_APPLICATION_TEMPLATE_PORTRAIT")
            .and_return("portrait_template_id")

          expect(service.send(:gdoc_template_id)).to eq "portrait_template_id"
        end
      end

      context "when document has landscape orientation" do
        let(:document) do
          double("DocumentPresenter", orientation: "landscape", gdoc_footer: [], gdoc_header: [])
        end

        it "returns landscape template ID from ENV" do
          allow(ENV).to receive(:fetch)
            .with("GOOGLE_APPLICATION_TEMPLATE_LANDSCAPE")
            .and_return("landscape_template_id")

          expect(service.send(:gdoc_template_id)).to eq "landscape_template_id"
        end
      end

      context "when document orientation is nil" do
        let(:document) do
          double("DocumentPresenter", orientation: nil, gdoc_footer: [], gdoc_header: [])
        end

        it "defaults to portrait template" do
          allow(ENV).to receive(:fetch)
            .with("GOOGLE_APPLICATION_TEMPLATE_PORTRAIT")
            .and_return("portrait_template_id")

          expect(service.send(:gdoc_template_id)).to eq "portrait_template_id"
        end
      end
    end

    describe "#parameters" do
      context "when document has portrait orientation" do
        let(:document) do
          double(
            "DocumentPresenter",
            orientation: "portrait",
            gdoc_footer: [["{attribution}"], ["CC BY-NC-SA"]],
            gdoc_header: [["{title}"], ["Test Title"]]
          )
        end

        it "returns array with landscape flag as false" do
          params = service.send(:parameters)
          expect(params.first).to be false
        end

        it "includes footer data in parameters" do
          params = service.send(:parameters)
          expect(params).to include(["{attribution}"])
          expect(params).to include(["CC BY-NC-SA"])
        end

        it "includes header data in parameters" do
          params = service.send(:parameters)
          expect(params).to include(["{title}"])
          expect(params).to include(["Test Title"])
        end
      end

      context "when document has landscape orientation" do
        let(:document) do
          double(
            "DocumentPresenter",
            orientation: "landscape",
            gdoc_footer: [],
            gdoc_header: []
          )
        end

        it "returns array with landscape flag as true" do
          params = service.send(:parameters)
          expect(params.first).to be true
        end
      end

      context "when footer/header contain nil values" do
        let(:document) do
          double(
            "DocumentPresenter",
            orientation: "portrait",
            gdoc_footer: [["{attribution}"], [nil]],
            gdoc_header: [[nil], ["Test"]]
          )
        end

        it "replaces nil values with empty strings" do
          params = service.send(:parameters)
          expect(params).to include([""])
        end
      end
    end

    describe "#ensure_not_nil_params_for" do
      it "converts nil values to empty strings" do
        data = [[nil, "value"], ["key", nil]]
        result = service.send(:ensure_not_nil_params_for, data)

        expect(result).to eq [["", "value"], ["key", ""]]
      end

      it "returns nil when data is nil" do
        expect(service.send(:ensure_not_nil_params_for, nil)).to be_nil
      end
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

describe PluginSystem::CodeOverrides do
  describe ".problems" do
    it "finds none in the plugins in this repository" do
      expect(described_class.problems.map(&:message)).to be_empty
    end

    context "with given constant paths" do
      let(:core) { Rails.root.join("app/models/document.rb").to_s }
      let(:plugin_dir) { PluginSystem::PLUGINS_PATH.join("client_1") }

      subject(:problems) { described_class.problems(cpaths) }

      context "when a plugin file defines a core constant" do
        let(:cpaths) do
          { plugin_dir.join("app/models/document.rb").to_s => "Document", core => "Document" }
        end

        it "reports the plugin file" do
          expect(problems).to contain_exactly(
            have_attributes(
              plugin: "client_1",
              constant: "Document",
              file: "lib/plugins/client_1/app/models/document.rb",
              other_files: ["app/models/document.rb"]
            )
          )
          expect(problems.first.message).to include("only one of them is loaded")
        end
      end

      context "when two plugins define the same constant" do
        let(:cpaths) do
          {
            plugin_dir.join("lib/shared.rb").to_s => "Shared",
            PluginSystem::PLUGINS_PATH.join("client_2/lib/shared.rb").to_s => "Shared"
          }
        end

        it "reports both plugin files" do
          expect(problems.map(&:plugin)).to contain_exactly("client_1", "client_2")
        end
      end

      context "when a plugin adds constants inside a core namespace" do
        let(:cpaths) do
          {
            Rails.root.join("lib/exporters/pdf").to_s => "Exporters::Pdf",
            plugin_dir.join("lib/exporters/pdf").to_s => "Exporters::Pdf",
            plugin_dir.join("lib/exporters/pdf/student_book.rb").to_s => "Exporters::Pdf::StudentBook",
            core => "Document"
          }
        end

        it "accepts them, since a shared namespace directory is not a clash" do
          expect(problems).to be_empty
        end
      end
    end
  end
end

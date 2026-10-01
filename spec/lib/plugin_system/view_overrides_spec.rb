# frozen_string_literal: true

require "rails_helper"

describe PluginSystem::ViewOverrides do
  describe "DECLARED" do
    it "lists only templates core ships" do
      core = described_class.templates_in(Rails.root.join("app/views"))

      expect(described_class::DECLARED - core.to_a).to be_empty
    end
  end

  describe ".problems" do
    it "finds none in the plugins in this repository" do
      expect(described_class.problems.map(&:message)).to be_empty
    end

    context "with a plugin that overrides views" do
      let(:plugin_path) { Pathname(Dir.mktmpdir).join("client_1") }

      def add_view(path)
        file = plugin_path.join("app/views", path)
        FileUtils.mkdir_p(file.dirname)
        FileUtils.touch(file)
      end

      after { FileUtils.rm_rf(plugin_path.dirname) }

      subject(:problems) { described_class.problems([plugin_path]) }

      it "accepts an override of a declared template" do
        add_view("documents/pdf/_header.html.erb")

        expect(problems).to be_empty
      end

      it "accepts plugin-only views" do
        add_view("layouts/pdf_client.erb")
        add_view("admin/client_1/index.html.erb")

        expect(problems).to be_empty
      end

      it "reports an override of an undeclared core view" do
        add_view("documents/show.html.erb")

        expect(problems).to contain_exactly(
          have_attributes(plugin: "client_1", template: "documents/show", kind: :undeclared)
        )
        expect(problems.first.message).to include("not a declared override")
      end

      it "reports an override of a declared template core no longer ships" do
        stub_const("#{described_class}::DECLARED", described_class::DECLARED + %w(documents/pdf/_removed))
        add_view("documents/pdf/_removed.html.erb")

        expect(problems).to contain_exactly(
          have_attributes(plugin: "client_1", template: "documents/pdf/_removed", kind: :orphaned)
        )
      end
    end
  end

  describe ".templates_in" do
    it "strips format and handler extensions and skips dotfiles" do
      dir = Pathname(Dir.mktmpdir)
      FileUtils.mkdir_p(dir.join("layouts"))
      FileUtils.touch(dir.join("layouts/pdf.erb"))
      FileUtils.touch(dir.join("layouts/gdoc.html.erb"))
      FileUtils.touch(dir.join("layouts/.keep"))

      expect(described_class.templates_in(dir)).to eq(Set["layouts/pdf", "layouts/gdoc"])
    ensure
      FileUtils.rm_rf(dir)
    end
  end
end

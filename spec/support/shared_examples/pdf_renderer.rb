# frozen_string_literal: true

require "rails_helper"

#
# Conformance suite for PDF renderer plugins.
#
# Usage:
#
#   describe MyPdf::Renderer do
#     it_behaves_like "a PDF renderer"
#   end
#
# The examples verify the renderer satisfies the protocol that
# `Exporters::Pdf::RendererRegistry` validates at registration time, plus a
# few ergonomic checks (return types, registry round-trip). Runtime behavior
# (does `#call` actually produce a valid PDF?) is NOT exercised here —
# that requires the renderer's external dependencies to be installed and
# belongs in the plugin's own integration tests.
#
shared_examples "a PDF renderer" do
  describe "protocol conformance" do
    it "exposes a Symbol identifier" do
      expect(described_class.identifier).to be_a(Symbol)
    end

    it "implements #call as an instance method" do
      expect(described_class.public_method_defined?(:call)).to be(true)
    end

    it "accepts an `options:` keyword argument on #call" do
      params = described_class.instance_method(:call).parameters
      keyword_names = params.select { |type, _| %i(keyreq key).include?(type) }.map(&:last)
      expect(keyword_names).to include(:options)
    end

    it "advertises capabilities as a Set" do
      expect(described_class.capabilities).to be_a(Set)
    end

    it "implements .available? returning a Boolean" do
      expect([true, false]).to include(described_class.available?)
    end

    it "implements .layout_name returning a String" do
      expect(described_class.layout_name).to be_a(String)
    end
  end

  describe "registry integration" do
    around do |example|
      saved = Exporters::Pdf::RendererRegistry.instance_variable_get(:@store)&.dup
      Exporters::Pdf::RendererRegistry.reset!
      example.run
    ensure
      Exporters::Pdf::RendererRegistry.instance_variable_set(:@store, saved || {})
    end

    it "registers without raising ContractViolation" do
      expect { Exporters::Pdf::RendererRegistry.register(described_class) }.not_to raise_error
    end

    it "appears under its identifier in RendererRegistry.all after registration" do
      Exporters::Pdf::RendererRegistry.register(described_class)
      expect(Exporters::Pdf::RendererRegistry.all).to include(described_class.identifier)
    end

    it "is fetchable by its identifier" do
      Exporters::Pdf::RendererRegistry.register(described_class)
      next unless described_class.available?

      backend = Exporters::Pdf::RendererRegistry.fetch(described_class.identifier)
      expect(backend).to be_a(described_class).or be(described_class)
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

describe Exporters::Pdf::RendererRegistry do
  # Save and restore the registry around each example so test-only registrations
  # do not leak into other specs (which rely on the boot-time :grover registration).
  around do |example|
    saved = described_class.instance_variable_get(:@store)&.dup
    described_class.reset!
    example.run
  ensure
    described_class.instance_variable_set(:@store, saved || {})
  end

  # Helper: build a renderer class on the fly with the given protocol shape.
  def build_renderer(identifier:, capabilities: [], available: true)
    Class.new do
      define_singleton_method(:identifier)   { identifier }
      define_singleton_method(:capabilities) { Set.new(capabilities) }
      define_singleton_method(:available?)   { available }
      define_method(:call) { |_html, options:| "%PDF-1.4\n" }
    end
  end

  describe ".register" do
    it "stores a class that satisfies the protocol" do
      klass = build_renderer(identifier: :alpha)
      described_class.register(klass)
      expect(described_class.all).to eq([:alpha])
    end

    it "stores an instance that satisfies the protocol" do
      klass = build_renderer(identifier: :beta)
      described_class.register(klass.new)
      expect(described_class.all).to eq([:beta])
    end

    it "rejects a class missing the #call instance method" do
      bad = Class.new do
        define_singleton_method(:identifier) { :no_call }
      end
      expect { described_class.register(bad) }
        .to raise_error(described_class::ContractViolation, /instance.*call/)
    end

    it "rejects a class missing the .identifier class method" do
      bad = Class.new do
        define_method(:call) { |_html, options:| "" }
      end
      expect { described_class.register(bad) }
        .to raise_error(described_class::ContractViolation, /class.*identifier/)
    end

    it "replaces a prior registration with the same identifier" do
      first  = build_renderer(identifier: :gamma)
      second = build_renderer(identifier: :gamma)
      described_class.register(first)
      described_class.register(second)
      expect(described_class.fetch(:gamma)).to be_a(second)
    end
  end

  describe ".fetch" do
    it "returns an instance for a class registration" do
      klass = build_renderer(identifier: :alpha)
      described_class.register(klass)
      expect(described_class.fetch(:alpha)).to be_a(klass)
    end

    it "returns the same instance for an instance registration" do
      klass    = build_renderer(identifier: :beta)
      instance = klass.new
      described_class.register(instance)
      expect(described_class.fetch(:beta)).to be(instance)
    end

    it "raises RendererNotFound for an unknown identifier" do
      expect { described_class.fetch(:missing) }
        .to raise_error(described_class::RendererNotFound)
    end

    it "raises RendererUnavailable for a registered-but-unavailable backend" do
      klass = build_renderer(identifier: :delta, available: false)
      described_class.register(klass)
      expect { described_class.fetch(:delta) }
        .to raise_error(described_class::RendererUnavailable)
    end
  end

  describe ".fetch_for" do
    it "returns the backend when no accessibility is required" do
      klass = build_renderer(identifier: :alpha)
      described_class.register(klass)
      expect(described_class.fetch_for(identifier: :alpha)).to be_a(klass)
    end

    it "returns the backend when capability requirement is met" do
      klass = build_renderer(identifier: :prince_like, capabilities: %i(pdf_ua tagged_pdf))
      described_class.register(klass)
      expect(described_class.fetch_for(identifier: :prince_like, accessibility: :pdf_ua))
        .to be_a(klass)
    end

    it "raises UnsupportedCapability when the backend lacks required capability" do
      klass = build_renderer(identifier: :grover_like)
      described_class.register(klass)
      expect { described_class.fetch_for(identifier: :grover_like, accessibility: :pdf_ua) }
        .to raise_error(described_class::UnsupportedCapability, /missing capabilities: pdf_ua/)
    end

    it "raises ArgumentError for unknown accessibility level" do
      klass = build_renderer(identifier: :alpha)
      described_class.register(klass)
      expect { described_class.fetch_for(identifier: :alpha, accessibility: :pdf_x) }
        .to raise_error(ArgumentError, /unknown accessibility level/)
    end
  end

  describe ".available / .all" do
    before do
      described_class.register(build_renderer(identifier: :one))
      described_class.register(build_renderer(identifier: :two, available: false))
    end

    it "returns only available identifiers from .available" do
      expect(described_class.available).to eq([:one])
    end

    it "returns all registered identifiers from .all" do
      expect(described_class.all).to contain_exactly(:one, :two)
    end
  end

  describe ".default" do
    around do |example|
      original = ENV[described_class::DEFAULT_RENDERER_ENV]
      example.run
    ensure
      ENV[described_class::DEFAULT_RENDERER_ENV] = original
    end

    it "falls back to :grover when env is unset" do
      ENV.delete(described_class::DEFAULT_RENDERER_ENV)
      expect(described_class.default).to eq(:grover)
    end

    it "reads from DEFAULT_PDF_RENDERER env" do
      ENV[described_class::DEFAULT_RENDERER_ENV] = "prince"
      expect(described_class.default).to eq(:prince)
    end
  end

  describe ".unregister" do
    it "removes a previously registered backend" do
      described_class.register(build_renderer(identifier: :temp))
      described_class.unregister(:temp)
      expect(described_class.all).to be_empty
    end
  end
end

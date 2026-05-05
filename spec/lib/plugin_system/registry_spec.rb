# frozen_string_literal: true

require "rails_helper"

describe PluginSystem::Registry do
  # A minimal host that extends the mixin and declares the protocol.
  let(:host) do
    Module.new do
      extend PluginSystem::Registry

      const_set(:REQUIRED_INSTANCE_METHODS, %i(perform).freeze)
      const_set(:REQUIRED_CLASS_METHODS,    %i(identifier).freeze)
    end
  end

  def build_backend(identifier:, available: true)
    Class.new do
      define_singleton_method(:identifier) { identifier }
      define_singleton_method(:available?) { available }
      define_method(:perform) { |*| "result" }
    end
  end

  describe "#register" do
    it "stores a class that satisfies the protocol" do
      host.register(build_backend(identifier: :alpha))
      expect(host.all).to eq([:alpha])
    end

    it "stores an instance that satisfies the protocol" do
      host.register(build_backend(identifier: :beta).new)
      expect(host.all).to eq([:beta])
    end

    it "rejects a backend missing a required instance method" do
      bad = Class.new do
        define_singleton_method(:identifier) { :no_perform }
      end
      expect { host.register(bad) }
        .to raise_error(PluginSystem::Registry::ContractViolation, /instance.*perform/)
    end

    it "rejects a backend missing a required class method" do
      bad = Class.new do
        define_method(:perform) { |*| "" }
      end
      expect { host.register(bad) }
        .to raise_error(PluginSystem::Registry::ContractViolation, /class.*identifier/)
    end
  end

  describe "#fetch" do
    it "returns an instance for a class registration" do
      klass = build_backend(identifier: :alpha)
      host.register(klass)
      expect(host.fetch(:alpha)).to be_a(klass)
    end

    it "returns the same instance for an instance registration" do
      instance = build_backend(identifier: :beta).new
      host.register(instance)
      expect(host.fetch(:beta)).to be(instance)
    end

    it "raises NotFound for an unknown identifier" do
      expect { host.fetch(:missing) }
        .to raise_error(PluginSystem::Registry::NotFound)
    end

    it "raises Unavailable when the backend reports available? false" do
      host.register(build_backend(identifier: :gamma, available: false))
      expect { host.fetch(:gamma) }
        .to raise_error(PluginSystem::Registry::Unavailable)
    end
  end

  describe "#available / #all" do
    before do
      host.register(build_backend(identifier: :one))
      host.register(build_backend(identifier: :two, available: false))
    end

    it "returns only available identifiers from #available" do
      expect(host.available).to eq([:one])
    end

    it "returns all registered identifiers from #all" do
      expect(host.all).to contain_exactly(:one, :two)
    end
  end

  describe "#unregister and #reset!" do
    before { host.register(build_backend(identifier: :temp)) }

    it "removes a previously registered backend" do
      host.unregister(:temp)
      expect(host.all).to be_empty
    end

    it "clears all registrations" do
      host.reset!
      expect(host.all).to be_empty
    end
  end
end

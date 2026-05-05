# frozen_string_literal: true

module PluginSystem
  #
  # Generic registry-of-backends pattern. Extracted from Pdf::RendererRegistry
  # so other format registries (Gdoc::PublisherRegistry, Docx::RendererRegistry,
  # ...) can reuse the same mechanics: protocol-verified registration, fetch
  # with availability gating, list of available/all identifiers, test reset.
  #
  # Consumers `extend` this module and declare two protocol constants:
  #
  #   module Exporters::Pdf::RendererRegistry
  #     extend PluginSystem::Registry
  #
  #     REQUIRED_INSTANCE_METHODS = %i(call).freeze
  #     REQUIRED_CLASS_METHODS    = %i(identifier).freeze
  #   end
  #
  # Format-specific extensions (capability gating, default identifier,
  # error subclasses) stay on the format's registry.
  #
  module Registry
    Error             = Class.new(StandardError)
    NotFound          = Class.new(Error)
    Unavailable       = Class.new(Error)
    ContractViolation = Class.new(ArgumentError)

    def register(backend)
      klass = klass_of(backend)
      verify_contract!(klass)
      store[klass.identifier.to_sym] = backend
    end

    def unregister(identifier)
      store.delete(identifier.to_sym)
    end

    def fetch(identifier)
      backend = store[identifier.to_sym]
      raise NotFound, "no backend registered for: #{identifier.inspect}" unless backend

      klass = klass_of(backend)
      unless klass.available?
        raise Unavailable, "#{identifier.inspect} is registered but not available on this host"
      end

      backend.is_a?(Class) ? backend.new : backend
    end

    # Identifiers of registered backends whose `available?` returns true.
    def available
      store.select { |_, b| klass_of(b).available? }.keys
    end

    # Identifiers of all registered backends, regardless of availability.
    def all
      store.keys
    end

    # Reset the registry. Test-only.
    def reset!
      @store = {}
    end

    private

    def store
      @store ||= {}
    end

    # Resolves the registrable class from a Class or instance backend.
    # Untyped boundary by design — the contract is duck-typed, so callers
    # treat the return as opaque and rely on verify_contract! for safety.
    def klass_of(backend)
      backend.is_a?(Class) ? backend : backend.class
    end

    def verify_contract!(klass)
      missing_class    = self::REQUIRED_CLASS_METHODS.reject    { |m| klass.respond_to?(m) }
      missing_instance = self::REQUIRED_INSTANCE_METHODS.reject { |m| klass.public_method_defined?(m) }
      return if missing_class.empty? && missing_instance.empty?

      raise ContractViolation,
            "#{klass} missing required methods " \
            "(class: #{missing_class}, instance: #{missing_instance})"
    end
  end
end

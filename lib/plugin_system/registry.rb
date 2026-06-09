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
  # Beyond the required protocol methods, registries may also use optional
  # backend class methods such as `.available?`. When omitted, the mixin
  # falls back to sensible defaults (for availability, `true`).
  #
  module Registry
    Error = Class.new(StandardError)
    NotFound = Class.new(Error)
    Unavailable = Class.new(Error)
    AlreadyRegistered = Class.new(Error)
    ContractViolation = Class.new(ArgumentError)

    def register(backend)
      klass = klass_of(backend)
      verify_contract!(klass)
      identifier = klass.identifier.to_sym
      if store.key?(identifier)
        raise AlreadyRegistered,
              "backend #{identifier.inspect} is already registered " \
              "(existing: #{klass_of(store[identifier])}, attempted: #{klass})"
      end
      store[identifier] = backend
    end

    def unregister(identifier)
      store.delete(identifier.to_sym)
    end

    def fetch(identifier)
      key = identifier.to_sym
      backend = store[key]
      unless backend
        raise NotFound,
              "no backend registered for: #{identifier.inspect} " \
              "(registered: #{store.keys.inspect})"
      end

      klass = klass_of(backend)
      unless available_class?(klass)
        raise Unavailable, "#{identifier.inspect} is registered but not available on this host"
      end

      backend.is_a?(Class) ? backend.new : backend
    end

    # Identifiers of registered backends whose `available?` returns true.
    def available
      store.select { |_, b| available_class?(klass_of(b)) }.keys
    end

    # Identifiers of all registered backends, regardless of availability.
    def all
      store.keys
    end

    # Reset the registry. Test-only — raises in any non-test environment to
    # prevent accidental wipe of registered backends in dev/staging/prod.
    def reset!
      unless defined?(Rails) && Rails.env.test?
        raise Error, "Registry#reset! is only allowed in the test environment"
      end
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
      missing_class = self::REQUIRED_CLASS_METHODS.reject { |m| klass.respond_to?(m) }
      missing_instance = self::REQUIRED_INSTANCE_METHODS.reject { |m| klass.public_method_defined?(m) }
      return if missing_class.empty? && missing_instance.empty?

      raise ContractViolation,
            "#{klass} missing required methods " \
            "(class: #{missing_class}, instance: #{missing_instance})"
    end

    def available_class?(klass)
      klass.respond_to?(:available?) ? klass.available? : true
    end
  end
end

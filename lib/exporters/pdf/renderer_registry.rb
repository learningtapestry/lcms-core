# frozen_string_literal: true

module Exporters
  module Pdf
    #
    # Runtime registry of PDF renderer backends.
    #
    # Backends register themselves at boot (default backends in core
    # initializers, plugin backends in their setup! hooks). The registry
    # validates the renderer protocol at registration time so malformed
    # backends fail loudly when they are loaded, not at first render.
    #
    # Resolution: callers fetch by identifier and required accessibility
    # level. The registry rejects combinations the requested backend
    # cannot satisfy (e.g. :grover + :pdf_ua) before any HTML is rendered.
    #
    # The generic register/fetch/available/all/reset mechanics live in
    # PluginSystem::Registry. PDF-specific extensions (capability gating,
    # default identifier from env) live here.
    #
    module RendererRegistry
      extend PluginSystem::Registry

      REQUIRED_INSTANCE_METHODS = %i(call).freeze
      REQUIRED_CLASS_METHODS    = %i(identifier).freeze

      CAPABILITY_FOR_ACCESSIBILITY = {
        none: [].freeze,
        tagged: %i(tagged_pdf).freeze,
        pdf_ua: %i(pdf_ua).freeze
      }.freeze

      DEFAULT_RENDERER_ENV = "DEFAULT_PDF_RENDERER"
      FALLBACK_DEFAULT     = :grover

      # Backward-compatible aliases for the generic errors raised by the
      # mixin. Existing consumers can rescue using the PDF-flavored names.
      RendererNotFound    = PluginSystem::Registry::NotFound
      RendererUnavailable = PluginSystem::Registry::Unavailable
      ContractViolation   = PluginSystem::Registry::ContractViolation

      # PDF-specific errors.
      class RenderError           < StandardError; end
      class UnsupportedCapability < StandardError; end

      class << self
        #
        # Look up a renderer that can satisfy a given accessibility level.
        # Raises UnsupportedCapability if the backend lacks required
        # capabilities (e.g. :grover asked for :pdf_ua).
        #
        def fetch_for(identifier:, accessibility: :none)
          backend  = fetch(identifier)
          required = CAPABILITY_FOR_ACCESSIBILITY.fetch(accessibility) do
            raise ArgumentError, "unknown accessibility level: #{accessibility.inspect}"
          end
          missing = required - backend.class.capabilities.to_a
          return backend if missing.empty?

          raise UnsupportedCapability,
                "#{identifier} cannot satisfy accessibility=#{accessibility} " \
                "(missing capabilities: #{missing.join(', ')})"
        end

        def default
          ENV.fetch(DEFAULT_RENDERER_ENV, FALLBACK_DEFAULT.to_s).to_sym
        end
      end
    end
  end
end

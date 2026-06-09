# frozen_string_literal: true

module Exporters
  module Pdf
    module Renderers
      #
      # Optional ergonomic base class for PDF renderers.
      #
      # Provides defaults for the optional parts of the renderer protocol
      # so plugin authors only override what differs. Inheriting Base is
      # not required — any object that satisfies the protocol can be
      # registered. The protocol is enforced by RendererRegistry at
      # registration time, not by this class.
      #
      # The protocol:
      #   #call(html, options:) -> String   (required, PDF bytes)
      #   .identifier           -> Symbol   (required, stable name)
      #   .capabilities         -> Set[Symbol]  (optional, default: empty)
      #   .available?           -> Boolean      (optional, default: true)
      #   .layout_name          -> String       (optional, default: "pdf")
      #
      # `#call` and `.identifier` are deliberately NOT defined here.
      # Defining them with raise NotImplementedError would defeat the
      # protocol verifier — the inherited methods would satisfy the
      # method-defined check while still failing at runtime.
      #
      class Base
        EMPTY_CAPABILITIES = Set.new.freeze
        DEFAULT_LAYOUT     = "pdf"

        def self.capabilities = EMPTY_CAPABILITIES
        def self.available?   = true
        def self.layout_name  = DEFAULT_LAYOUT
      end
    end
  end
end

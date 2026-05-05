# frozen_string_literal: true

module PrincePdf
  #
  # PDF renderer backed by the PrinceXML command-line tool.
  #
  # Implements Exporters::Pdf::Renderers::Base. Inherits the optional-method
  # defaults from Base; overrides identifier, capabilities, layout_name,
  # available?, and provides the required #call.
  #
  # Capabilities advertise PDF/UA-1 and tagged-PDF support so the registry's
  # accessibility-capability gate accepts :tagged and :pdf_ua requests
  # against this renderer.
  #
  # Available? returns false when the prince binary cannot be invoked,
  # which causes the registry to filter :prince out of `.available`.
  # Records requesting :prince in that state fail fast with
  # RendererUnavailable rather than silently downgrading to Grover.
  #
  class Renderer < ::Exporters::Pdf::Renderers::Base
    CAPABILITIES = Set[
      :landscape,
      :tagged_pdf,
      :pdf_ua,
      :running_headers,
      :web_fonts,
      :js_execution,
      :custom_script_hook,
      :background_print
    ].freeze

    def self.identifier   = :prince
    def self.capabilities = CAPABILITIES
    def self.layout_name  = "pdf_prince"

    def self.available?
      Executable.present?
    end

    def call(html, options:)
      args = OptionsTranslator.new(options).to_args
      Executable.run(args, stdin: html)
    rescue Executable::NonZeroExit => e
      raise ::Exporters::Pdf::RendererRegistry::RenderError,
            "PrinceXML failed: #{e.message}"
    end
  end
end

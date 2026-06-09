# frozen_string_literal: true

module Exporters
  module Pdf
    module Renderers
      #
      # Default PDF renderer. Wraps the Grover gem (headless Chromium via
      # Puppeteer) and translates RenderOptions into Grover's option hash.
      #
      # Grover-specific configuration (executable path, sandbox flags,
      # timeout) lives in config/initializers/grover.rb and is read from
      # the Grover global by ::Grover.new.
      #
      class Grover < Base
        CAPABILITIES = Set[
          :landscape,
          :background_print,
          :running_headers,
          :web_fonts,
          :js_execution
        ].freeze

        def self.identifier = :grover
        def self.capabilities = CAPABILITIES

        def call(html, options:)
          ::Grover.new(html, **translate(options)).to_pdf
        end

        private

        def translate(opts)
          {
            format: opts.format,
            landscape: opts.landscape?,
            margin: opts.margin,
            dpi: opts.dpi,
            print_background: opts.print_background,
            prefer_css_page_size: false,
            display_header_footer: !(opts.header_html.nil? && opts.footer_html.nil?),
            header_template: opts.header_html,
            footer_template: opts.footer_html
          }.compact.merge(opts.extra || {})
        end
      end
    end
  end
end

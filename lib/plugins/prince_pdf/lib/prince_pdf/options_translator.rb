# frozen_string_literal: true

module PrincePdf
  #
  # Translates a renderer-neutral RenderOptions into the array of PrinceXML
  # CLI arguments. Output shape is validated by the production reference
  # implementation in dese-lcms (see ADR-0001 §4.5).
  #
  # Example output:
  #   ["-", "--output=-",
  #    "--license-file=/etc/prince/license.dat",
  #    "--style=/.../prince_xml.css",
  #    "--style=/.../prince_xml_portrait.css",
  #    "--page-margin=\"0.5in 1in 0.5in 0.5in\"",
  #    "--script=/.../prince_xml.js",
  #    "--javascript",
  #    "--http-timeout=30",
  #    "--pdf-profile=PDF/UA-1"]
  #
  class OptionsTranslator
    ASSETS_DIR      = File.expand_path("assets", __dir__)
    BASE_STYLESHEET = File.join(ASSETS_DIR, "prince_xml.css")
    SCRIPT          = File.join(ASSETS_DIR, "prince_xml.js")
    HTTP_TIMEOUT    = "30"
    PDF_UA_PROFILE  = "PDF/UA-1"

    def initialize(options)
      @options = options
    end

    def to_args
      [
        "-", "--output=-",
        *license_args,
        *stylesheet_args,
        *margin_args,
        *script_args,
        "--javascript",
        "--http-timeout=#{HTTP_TIMEOUT}",
        *accessibility_args
      ]
    end

    private

    attr_reader :options

    def license_args
      license = ENV.fetch("PRINCE_LICENSE_PATH", nil)
      license ? ["--license-file=#{license}"] : []
    end

    def stylesheet_args
      # Defense-in-depth: RenderOptions.build validates orientation, but a
      # caller may bypass it via RenderOptions.new(...). Re-check here so the
      # value can never reach a File.join interpolation as an arbitrary path.
      orientation = options.orientation
      unless Exporters::Pdf::RenderOptions::ALLOWED_ORIENTATION.include?(orientation)
        raise ArgumentError, "invalid orientation: #{orientation.inspect}"
      end

      orientation_css = File.join(ASSETS_DIR, "prince_xml_#{orientation}.css")
      ["--style=#{BASE_STYLESHEET}", "--style=#{orientation_css}"]
    end

    def margin_args
      m = options.margin
      return [] unless m

      [%(--page-margin="#{m[:top]} #{m[:right]} #{m[:bottom]} #{m[:left]}")]
    end

    def script_args
      ["--script=#{SCRIPT}"]
    end

    def accessibility_args
      case options.accessibility
      when :none   then []
      when :tagged then ["--tagged-pdf"]
      when :pdf_ua then ["--pdf-profile=#{PDF_UA_PROFILE}"]
      else
        raise ArgumentError, "unknown accessibility level: #{options.accessibility.inspect}"
      end
    end
  end
end

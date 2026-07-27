# frozen_string_literal: true

module Exporters
  module Pdf
    #
    # Renderer-neutral configuration for one PDF rendering operation.
    #
    # Single source of truth for both the rendering engine (margins, format,
    # accessibility profile, ...) and the templates (header visibility,
    # name/date fields, padding, ...). Renderers consume the engine-relevant
    # subset; ERB templates consume the template-relevant subset; both read
    # from the same instance.
    #
    # Construct via `RenderOptions.build(...)` to pick up defaults.
    # Direct `RenderOptions.new(...)` is supported but requires every field.
    #
    # `source` is a Tier-2 programmatic seam (see Exporters::Pdf::Base): the
    # exporter threads the document/material presenter through here so renderers
    # that need the record itself — not just its rendered HTML — can reach it.
    # Most renderers ignore it. Unlike `extra` (which renderers may spread into
    # their engine options, e.g. Grover), `source` is a dedicated field so it
    # never leaks into an engine's option hash. It is an in-process handle and
    # is never serialized.
    RenderOptions = Data.define(
      :format,
      :orientation,
      :margin,
      :dpi,
      :image_dpi,
      :print_background,
      :header_html,
      :footer_html,
      :metadata,
      :accessibility,
      :show_header,
      :show_name_date,
      :padding,
      :extra,
      :source
    )

    class RenderOptions
      ALLOWED_ACCESSIBILITY = %i(none tagged pdf_ua).freeze
      ALLOWED_ORIENTATION = %i(portrait landscape).freeze

      DEFAULTS = {
        format: "Letter",
        orientation: :portrait,
        margin: nil,
        dpi: nil,
        image_dpi: nil,
        print_background: true,
        header_html: nil,
        footer_html: nil,
        metadata: {}.freeze,
        accessibility: :none,
        show_header: true,
        show_name_date: false,
        padding: nil,
        extra: {}.freeze,
        source: nil
      }.freeze

      def self.build(**overrides)
        attrs = DEFAULTS.merge(overrides)
        attrs[:orientation] = attrs[:orientation].to_s.downcase.to_sym if attrs[:orientation]
        validate!(attrs)
        new(**attrs)
      end

      def self.validate!(attrs)
        unless ALLOWED_ACCESSIBILITY.include?(attrs[:accessibility])
          raise ArgumentError,
                "accessibility must be one of #{ALLOWED_ACCESSIBILITY}, got #{attrs[:accessibility].inspect}"
        end
        unless ALLOWED_ORIENTATION.include?(attrs[:orientation])
          raise ArgumentError,
                "orientation must be one of #{ALLOWED_ORIENTATION}, got #{attrs[:orientation].inspect}"
        end
      end

      def landscape? = orientation == :landscape
      def portrait? = !landscape?
      def accessible? = accessibility != :none
    end
  end
end

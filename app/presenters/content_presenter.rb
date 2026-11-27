# frozen_string_literal: true

class ContentPresenter < BasePresenter
  DEFAULT_CONFIG = :default
  # Upper bound on the base64 brandmark passed inline to the Apps Script. The
  # bytes ride inside the scripts.run request body, which has a size ceiling, so
  # an unexpectedly large upload degrades to "no logo" instead of bloating (or
  # failing) the request. A real header logo is a few KB; 1 MB is generous.
  BRANDMARK_MAX_ENCODED_BYTES = 1.megabyte

  # PDF rendering config, read through the cached `Settings` interface
  # (Rails.cache-backed and auto-invalidated on write). The DB may be
  # unavailable during `assets:precompile` and similar no-database tasks, so
  # fall back to the shipped defaults in that case.
  def self.base_config
    Settings.get(:pdf, include_defaults: true) || {}
  rescue ActiveRecord::StatementInvalid,
         ActiveRecord::NoDatabaseError,
         ActiveRecord::ConnectionNotEstablished
    Settings::DEFAULTS[:pdf]
  end

  def base_filename
    name = short_breadcrumb(join_with: "_", with_short_lesson: true)
    "#{name}_v#{version.presence || 1}"
  end

  # Client logo/brandmark for the document banner, from Settings.
  #
  # Inlined as a data URI so the image survives HTML→Gdoc import (and the
  # gdoc_pdf renderer, which routes PDF through Drive). Falls back to the raw
  # URL if the fetch fails — works for Grover/Chromium.
  def brandmark_url
    inline_image_url(brandmark_source_url)
  end

  # Raw brandmark URL from Settings, NOT inlined as a data URI. Used as the
  # source both for #brandmark_url (PDF/inline HTML) and #brandmark_data_uri
  # (Gdoc). Blank when no brandmark is configured.
  def brandmark_source_url
    settings_image_source_url(:brandmark)
  end

  # Base64 data URI of the brandmark for the Gdoc running header. The Apps
  # Script (config/scripts/Code.gs) decodes this and inserts it at the
  # {brandmark_url} placeholder. Passing the bytes inline avoids UrlFetchApp in
  # the script (and its script.external_request OAuth scope) and the need for
  # the source URL to be publicly fetchable by Google — Rails inlines it once
  # (cached) from a URL only it must reach. Blank when no brandmark is
  # configured, inlining fails, or the encoded image exceeds
  # BRANDMARK_MAX_ENCODED_BYTES (so an oversized upload degrades to "no logo").
  def brandmark_data_uri
    inline_image_data_uri(brandmark_source_url, label: "brandmark")
  end

  # Client Creative Commons badge for the bundled-document footer, from
  # Settings. Same inlining as #brandmark_url.
  def cc_logo_url
    inline_image_url(cc_logo_source_url)
  end

  # Base64 data URI of the CC badge for the Gdoc running footer, inserted by the
  # Apps Script at the {cc_logo} placeholder. Same contract as
  # #brandmark_data_uri.
  def cc_logo_data_uri
    inline_image_data_uri(cc_logo_source_url, label: "cc_logo")
  end

  # Raw CC badge URL from Settings. Blank when none is configured.
  def cc_logo_source_url
    settings_image_source_url(:cc_logo)
  end

  def config
    @config ||= begin
      base = self.class.base_config
      base[DEFAULT_CONFIG].deep_merge(base[content_type.to_sym] || {})
    end
  end

  def content_type
    @content_type.presence || "unknown_content_type"
  end

  def footer_margin_styles
    padding_styles(align_type: "margin")
  end

  def gdoc_folder
    "#{id}_v#{version}"
  end

  def gdoc_preview_title
    preview_links.dig("preview", "gdoc").present? ? I18n.t("admin.common.preview_gdoc") : I18n.t("admin.common.generate_gdoc")
  end

  def initialize(obj, opts = {})
    super(obj)
    opts.each_pair do |key, value|
      instance_variable_set("@#{key}", value)
    end
  end

  def orientation
    render_options.orientation
  end

  def padding_styles(align_type: "padding")
    render_options.padding.map { |k, v| "#{align_type}-#{k}:#{v};" }.join
  end

  def pdf_preview_title
    preview_links.dig("preview", "pdf").present? ? I18n.t("admin.common.preview_pdf") : I18n.t("admin.common.generate_pdf")
  end

  #
  # Single source of truth for rendering-time configuration.
  # Renderer reads engine-relevant fields; templates read template-relevant
  # fields (via @render_options assigned by Exporters::Base#render_template).
  # Subclasses override `effective_orientation` to layer per-record overrides
  # on top of the per-content-type config.
  #
  def render_options
    @render_options ||= Exporters::Pdf::RenderOptions.build(
      format: "Letter",
      orientation: effective_orientation,
      margin: config[:margin],
      dpi: config[:dpi],
      image_dpi: config[:image_dpi],
      print_background: true,
      metadata: { title: base_filename, lang: "en" },
      accessibility: :none,
      show_header: config.fetch(:header, true),
      show_name_date: config[:name_date] == true,
      padding: config[:padding] || {}
    )
  end

  private

  def settings_image_source_url(key)
    Settings.get(:documents, include_defaults: true)&.dig(key).presence
  end

  def inline_image_url(raw)
    return nil if raw.blank?

    AssetHelper.inline_data_uri(raw, cache: ViewHelper::ENABLE_BASE64_CACHING) || raw
  end

  def inline_image_data_uri(raw, label:)
    return "" if raw.blank?

    data_uri = AssetHelper.inline_data_uri(raw, cache: ViewHelper::ENABLE_BASE64_CACHING)
    return "" if data_uri.blank?

    if data_uri.bytesize > BRANDMARK_MAX_ENCODED_BYTES
      Rails.logger.warn "[Gdoc] #{label} skipped: encoded image #{data_uri.bytesize} bytes exceeds #{BRANDMARK_MAX_ENCODED_BYTES}"
      return ""
    end

    data_uri
  end

  def effective_orientation
    config[:orientation] || "portrait"
  end

  def document_parts_index
    @document_parts_index ||= document_parts.pluck(:placeholder, :anchor, :content, :optional)
                                            .to_h { |p| [p[0], { anchor: p[1], content: p[2], optional: p[3] }] }
  end

  def layout_content(context_type)
    layout(context_type)&.content.to_s
  end
end

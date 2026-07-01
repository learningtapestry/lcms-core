# frozen_string_literal: true

class ContentPresenter < BasePresenter
  DEFAULT_CONFIG = :default
  MATERIALS_CONFIG_PATH = Rails.root.join("config", "materials_rules.yml")

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

  def self.materials_config
    @materials_config ||= YAML.load_file(MATERIALS_CONFIG_PATH, aliases: true).deep_symbolize_keys
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
    raw = Settings.get(:documents, include_defaults: true)&.dig(:brandmark)
    return nil if raw.blank?

    AssetHelper.inline_data_uri(raw, cache: ViewHelper::ENABLE_BASE64_CACHING) || raw
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

  def materials_config_for(type)
    self.class.materials_config[type.to_sym].flat_map do |k, v|
      v.map { |x| { k => x } }
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

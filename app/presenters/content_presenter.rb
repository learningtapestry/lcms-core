# frozen_string_literal: true

class ContentPresenter < BasePresenter
  CONFIG_PATH = Rails.root.join("config", "pdf.yml")
  DEFAULT_CONFIG = :default
  MATERIALS_CONFIG_PATH = Rails.root.join("config", "materials_rules.yml")

  def self.base_config
    @base_config ||= YAML.load_file(CONFIG_PATH, aliases: true).deep_symbolize_keys
  end

  def self.materials_config
    @materials_config ||= YAML.load_file(MATERIALS_CONFIG_PATH, aliases: true).deep_symbolize_keys
  end

  def base_filename
    name = short_breadcrumb(join_with: "_", with_short_lesson: true)
    "#{name}_v#{version.presence || 1}"
  end

  def config
    @config ||= self.class.base_config[DEFAULT_CONFIG].deep_merge(self.class.base_config[content_type.to_sym] || {})
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
    config[:orientation]
  end

  def padding_styles(align_type: "padding")
    config[:padding].map { |k, v| "#{align_type}-#{k}:#{v};" }.join
  end

  def pdf_preview_title
    preview_links.dig("preview", "pdf").present? ? I18n.t("admin.common.preview_pdf") : I18n.t("admin.common.generate_pdf")
  end

  private

  def document_parts_index
    @document_parts_index ||= document_parts.pluck(:placeholder, :anchor, :content, :optional)
                                            .to_h { |p| [p[0], { anchor: p[1], content: p[2], optional: p[3] }] }
  end

  def layout_content(context_type)
    layout(context_type)&.content.to_s
  end
end

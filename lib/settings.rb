# frozen_string_literal: true

# Settings is the public interface for reading and writing application
# settings. It hides the persistence (the `Setting` ActiveRecord model) and
# the caching layer (`Rails.cache`) behind a small set of class methods.
#
# Callers should always go through this module — never call `Setting.find_by`
# or other ActiveRecord methods directly. Doing so bypasses the cache.
#
#   Settings.get(:appearance, include_defaults: true)
#   Settings.set(:doc_template, sanitizer: "MyApp::Sanitizer")
#   Settings.unset(:appearance)
#
module Settings
  CACHE_PREFIX = "settings"

  DEFAULTS = {
    appearance: {
      header_bg_color: "#f8f9fa",
      header_text_color: "#000000",
      header_dropdown_bg_color: "#ffffff",
      header_active_item_color: "#0d6efd",
      header_logo: nil
    },
    doc_template: {
      contexts: %w(default gdoc),
      document_contexts: %w(default gdoc),
      material_contexts: %w(default gdoc pdf),
      metadata: {
        context: "Lt::Lcms::Metadata::Context",
        service: "Lt::Lcms::Metadata::Service"
      },
      queries: {
        document: "Admin::DocumentsQuery",
        material: "Admin::MaterialsQuery"
      },
      sanitizer: "HtmlSanitizer"
    },
    admin_view_links: {
      documents: ["/documents/:id"],
      materials: ["/materials/:id"],
      sections: ["/admin/sections#section_:id"],
      units: ["/admin/units#unit_:id"]
    }
  }.freeze

  class << self
    def get(key, include_defaults: false)
      Rails.cache.fetch(cache_key_for(key, include_defaults: include_defaults)) do
        record = Setting.find_by(key: key)
        db_settings = record&.value
        db_settings = merge_with_defaults(key, db_settings) if include_defaults
        db_settings
      end
    end

    def get_multiple(keys, include_defaults: false)
      keys.each_with_object({}) do |key, hash|
        hash[key.to_sym] = get(key, include_defaults: include_defaults)
      end
    end

    def set(key, value)
      return if value.nil?

      record = Setting.find_or_initialize_by(key: key)
      record.update!(value: value)
    end

    def unset(key)
      Setting.find_by(key: key)&.destroy
    end

    def unset_within(key, sub_key)
      settings = get(key)
      return unless settings

      settings = settings.dup
      settings.delete(sub_key.to_s)
      settings.blank? ? unset(key) : set(key, settings)
    end

    def merge_with_defaults(key, settings)
      defaults = DEFAULTS[key.to_sym]
      symbolized = (settings || {})
        .reject { |_k, v| v.blank? }
        .deep_symbolize_keys

      return symbolized unless defaults

      defaults.deep_merge(symbolized)
    end

    def cache_key_for(key, include_defaults: false)
      "#{CACHE_PREFIX}/#{key}#{"_with_defaults" if include_defaults}"
    end

    def expire_cache_for(key)
      Rails.cache.delete(cache_key_for(key))
      Rails.cache.delete(cache_key_for(key, include_defaults: true))
    end
  end
end

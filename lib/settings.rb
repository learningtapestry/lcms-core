# frozen_string_literal: true

# Settings is the public interface for reading and writing application
# settings. It hides the persistence (the `Setting` ActiveRecord model) and a
# dedicated, DB-backed cache (`Settings.cache`) behind a small set of class
# methods.
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
    },
    # Admin chrome. `layout` names a layout template that must exist in the
    # deployed code, so this is a code-level setting (not exposed in the admin
    # UI) — a fork overrides it by shipping a different DEFAULTS or setting the
    # :admin row directly.
    admin: {
      layout: "admin"
    },
    # PDF rendering settings consumed by the printers (see ContentPresenter
    # and Exporters::Pdf::Base). Keyed by content type: `default` holds the
    # base config, and any other key (e.g. `handout`) is deep-merged on top
    # of `default` for that content type.
    pdf: {
      # Top-level (not content-type-scoped): which registered PDF renderer the
      # app uses by default. Blank means "use the system fallback" (env var,
      # then RendererRegistry::FALLBACK_DEFAULT). Read by RendererRegistry.default.
      default_renderer: nil,
      default: {
        dpi: 72, # screen dpi to match font sizes
        image_dpi: 300,
        header: true,
        name_date: false,
        margin: {
          top: "0.5in",
          right: "1in",
          # 0.5in margin within 8pt footer + 7pt gap from footer to page content
          bottom: "0.5in",
          left: "0.5in"
        },
        orientation: "portrait",
        padding: {
          right: 0,
          left: 0
        }
      },
      handout: {
        name_date: true,
        margin: {
          top: "1.25in",
          right: "1.25in",
          # 1.25in margin within 8pt footer + 0.75in gap from footer to page content
          bottom: "1.25in",
          left: "1.25in"
        }
      }
    }
  }.freeze

  # Fingerprint of the in-code DEFAULTS, embedded in the cache key for
  # `include_defaults: true` reads. A deploy that ships a different DEFAULTS
  # hash gets a different fingerprint, so cached merged values from the old
  # deploy are not served — even if Redis survives the deploy and no Setting
  # row has changed. Computed once at module load; DEFAULTS is frozen.
  DEFAULTS_FINGERPRINT = Digest::SHA1.hexdigest(DEFAULTS.to_json).first(12).freeze

  class << self
    # Dedicated cache for settings, separate from the app's global Rails.cache.
    # In real environments it's the DB-backed Solid Cache store, so a write
    # invalidates the cache for EVERY web/worker process — letting the global
    # Rails.cache stay a fast per-process (or Redis) store for fragment caching.
    # In test it follows Rails.cache (null_store), so settings aren't cached
    # unless a spec opts in by assigning Settings.cache.
    attr_writer :cache

    def cache
      @cache ||= Rails.env.test? ? Rails.cache : ActiveSupport::Cache.lookup_store(:solid_cache_store)
    end

    def get(key, include_defaults: false)
      cache.fetch(cache_key_for(key, include_defaults: include_defaults)) do
        record = Setting.find_by(key: key)
        db_settings = record&.value
        db_settings = merge_with_defaults(key, db_settings) if include_defaults
        db_settings
      end
    end

    # N cached reads. At the current call sites N is 1, so a true batch
    # (read_multi + where) buys nothing. If N grows to 3+ and a profile
    # shows the Redis round-trips matter, swap this for
    # `Rails.cache.read_multi` + a single `Setting.where(key: missing)`.
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

    # Merges a stored value with the in-code defaults for the given key.
    #
    # The stored value can be a partial override — only the keys it specifies
    # are applied on top of the defaults. Two kinds of values are treated as
    # "use the default": `nil`, and blank strings (empty or whitespace-only,
    # per ActiveSupport's `String#blank?`). Empty collections (`[]`, `{}`),
    # `false`, and `0` are kept as intentional overrides. Stripping is
    # recursive, so a nested `metadata: { context: " " }` falls back to the
    # default `metadata.context` without poisoning the constantised
    # accessors in `DocTemplate`.
    def merge_with_defaults(key, settings)
      defaults = DEFAULTS[key.to_sym]
      cleaned = deep_reject_blank_strings((settings || {}).deep_symbolize_keys)

      return cleaned unless defaults

      defaults.deep_merge(cleaned)
    end

    def cache_key_for(key, include_defaults: false)
      base = "#{CACHE_PREFIX}/#{key}"
      return base unless include_defaults

      "#{base}_with_defaults/#{DEFAULTS_FINGERPRINT}"
    end

    def expire_cache_for(key)
      cache.delete(cache_key_for(key))
      cache.delete(cache_key_for(key, include_defaults: true))
    end

    private

    # Drops nil and blank-string values (recursively) so that defaults can
    # survive a `deep_merge`. Empty collections (`[]`, `{}`), `false`, `0`,
    # and other non-string falsy-adjacent values are preserved as
    # intentional overrides.
    def deep_reject_blank_strings(hash)
      hash.each_with_object({}) do |(k, v), result|
        case v
        when nil
          next
        when String
          result[k] = v unless v.blank?
        when Hash
          result[k] = deep_reject_blank_strings(v)
        else
          result[k] = v
        end
      end
    end
  end
end

# frozen_string_literal: true

class SettingsForm
  # A flat group whose schema is a Hash of `leaf_key => field_type` (e.g.
  # :appearance, :pdf). Values are scalar fields edited directly; image fields
  # upload their file and store the resulting URL. Always valid.
  class FlatGroup < BaseGroup
    def initialize(key, schema)
      super(key)
      @schema = schema
    end

    def apply(params)
      processed = process_image_uploads(params)
      submitted = processed.permit(field_keys).to_h
      # Compare against the defaults-merged values so a submission equal to the
      # current/default value is not persisted as a redundant override.
      changes = submitted.reject { |k, v| current_with_defaults[k.to_sym] == v }
      return if changes.empty?

      Settings.set(key, stored.merge(changes))
    end

    def reset(sub_key)
      if image_key?(sub_key)
        old_url = current_with_defaults&.dig(sub_key.to_sym)
        ImageUploader.delete_by_url(old_url)
      end
      Settings.unset_within(key, sub_key)
    end

    def to_partial_path
      "admin/settings/groups/flat"
    end

    # The schema (leaf_key => field_type) the view renders one row per.
    def fields
      @schema
    end

    # Current value of a leaf field, including defaults, for display.
    def value_for(field_key)
      current_with_defaults[field_key]
    end

    private

    def field_keys
      @schema.keys.map(&:to_s)
    end

    def image_keys
      @schema.select { |_k, type| type == :image }.keys.map(&:to_s)
    end

    def image_key?(sub_key)
      @schema[sub_key.to_sym] == :image
    end

    def stored
      Settings.get(key) || {}
    end

    def current_with_defaults
      Settings.get(key, include_defaults: true) || {}
    end

    # Uploads only this group's own image fields, so an image is never
    # re-uploaded once per group the way a global scan across SETTINGS would.
    # No-ops (returning the original params) when nothing was uploaded.
    def process_image_uploads(params)
      uploaded = image_keys.select { |k| params[k].respond_to?(:tempfile) }
      return params if uploaded.empty?

      modified = params.to_unsafe_h
      uploaded.each do |k|
        uploader = ImageUploader.new
        uploader.store!(params[k])
        modified[k] = uploader.url
      end
      ActionController::Parameters.new(modified)
    end
  end
end

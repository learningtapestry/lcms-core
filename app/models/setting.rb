class Setting < ApplicationRecord
  CACHE_PREFIX = "settings"

  validates :key, presence: true
  validates :value, presence: true

  after_commit :expire_cache

  class << self
    def cache_key_for(key, include_defaults: false)
      "#{CACHE_PREFIX}/#{key}#{"_with_defaults" if include_defaults}"
    end

    def get(key, include_defaults: false)
      result = find_by(key: key)
      db_settings = result&.value

      if include_defaults
        db_settings = merge_with_defaults(key, db_settings)
      end

      db_settings
    end

    def merge_with_defaults(key, settings)
      symbolized = (settings || {})
        .reject { |_k, v| v.blank? }
        .transform_keys(&:to_sym)

      SETTINGS_DEFAULTS[key.to_sym]&.merge(symbolized) || symbolized
    end

    def get_multiple(keys, include_defaults: false)
      settings_rows = where(key: keys)
      db_settings = settings_rows.each_with_object({}) do |row, hash|
        hash[row.key.to_sym] = row.value
      end

      return db_settings unless include_defaults

      keys.each do |key|
        db_settings[key.to_sym] = merge_with_defaults(key, db_settings[key.to_sym])
      end

      db_settings
    end

    def set(key, value)
      record = find_or_initialize_by(key: key)
      record.update!(value: value)
    end

    def unset(key)
      find_by(key: key)&.destroy
    end

    def unset_within(key, sub_key)
      settings = get(key)
      return unless settings

      settings.delete(sub_key.to_s)
      settings.blank? ? unset(key) : set(key, settings)
    end
  end

  private

  def expire_cache
    Rails.cache.delete(self.class.cache_key_for(key))
    Rails.cache.delete(self.class.cache_key_for(key, include_defaults: true))
  end
end

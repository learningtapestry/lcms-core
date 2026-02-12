class Setting < ApplicationRecord
  validates :key, presence: true
  validates :value, presence: true

  class << self
    def get(key)
      result = find_by(key: key).value
      result = merge_with_defaults(result)
      result[key]
    end

    def merge_with_defaults(settings)
      symbolized = settings.transform_keys(&:to_sym)
      SETTINGS_DEFAULTS.merge(symbolized)
    end

    def get_multiple(keys)
      settings_rows = where(key: keys)
      settings = settings_rows.each_with_object({}) { |row, hash| hash[row.key] = row.value }

      result = merge_with_defaults(settings)
      result
    end

    def set(key, value)
      setting = find_by(key: key)
      if setting.present?
        setting.update(value: value)
      else
        create(key: key, value: value)
      end
    end

    def set_multiple(settings)
      return if settings.empty?

      records = settings.map do |key, value|
        {
          key: key,
          value: value
        }
      end

      upsert_all(records, unique_by: :key, update_only: [:value])
    end

    def unset(key)
      find_by(key: key)&.destroy
    end
  end
end

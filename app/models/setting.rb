# frozen_string_literal: true

# == Schema Information
#
# Table name: settings
#
#  id         :bigint           not null, primary key
#  key        :string           not null
#  value      :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_settings_on_key  (key) UNIQUE
#
# Persistence model for application settings. Treat this as an internal
# implementation detail — the public API for reading and writing settings is
# the `Settings` module (see lib/settings.rb). Calling `Setting.find_by` /
# `Setting.update!` directly works but bypasses the read cache; the
# `after_commit` below keeps the cache consistent if you do.
class Setting < ApplicationRecord
  validates :key, presence: true

  after_commit :expire_settings_cache

  private

  def expire_settings_cache
    Settings.expire_cache_for(key)
  end
end

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
FactoryBot.define do
  factory :setting do
    sequence(:key) { |n| "setting_key_#{n}" }
    value { "setting_value" }
  end
end

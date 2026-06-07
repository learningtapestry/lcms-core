# frozen_string_literal: true

# == Schema Information
#
# Table name: access_codes
#
#  id         :integer          not null, primary key
#  active     :boolean          default(TRUE), not null
#  code       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_access_codes_on_code  (code) UNIQUE
#
class AccessCode < ApplicationRecord
  validates :code, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }
  scope :by_code, ->(value) { active.where("lower(code) = ?", value.downcase) }
end

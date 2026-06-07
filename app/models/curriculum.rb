# frozen_string_literal: true

# == Schema Information
#
# Table name: curriculums
#
#  id         :integer          not null, primary key
#  default    :boolean          default(FALSE), not null
#  name       :string           not null
#  slug       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Curriculum < ApplicationRecord
  has_many :resources, dependent: :nullify
  has_many :authors, -> { distinct }, through: :resources

  validates :name, :slug, presence: true, uniqueness: true

  def self.default
    where(default: true).first
  end
end

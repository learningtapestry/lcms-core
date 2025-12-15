# frozen_string_literal: true

class Standard < ApplicationRecord
  has_many :resource_standards, dependent: :destroy
  has_many :resources, through: :resource_standards

  validates :name, presence: true

  # NOTE: #954 - to be removed
  scope :by_grade, ->(grade) { by_grades [ grade ] }
  # NOTE: #954 - to be removed
  scope :by_grades, lambda { |grades|
    joins(resource_standards: { resource: [ :grades ] })
      .where("grades.id" => grades.map(&:id))
  }

  # NOTE: #954 - to be removed
  scope :ela, -> { where(subject: "ela") }
  scope :math, -> { where(subject: "math") }

  # NOTE: #954 - to be removed?
  def self.search_by_name(name)
    where("name ILIKE :q OR alt_names::text ILIKE :q", q: "%#{name}%").order(:id)
  end
end

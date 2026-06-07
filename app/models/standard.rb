# frozen_string_literal: true

# == Schema Information
#
# Table name: standards
#
#  id          :integer          not null, primary key
#  alt_names   :text             default([]), not null, is an Array
#  course      :string
#  description :string
#  domain      :string
#  emphasis    :string
#  grades      :text             default([]), not null, is an Array
#  label       :string
#  name        :string           not null
#  strand      :string
#  subject     :string
#  synonyms    :text             default([]), is an Array
#  created_at  :datetime
#  updated_at  :datetime
#
# Indexes
#
#  index_standards_on_name     (name)
#  index_standards_on_subject  (subject)
#
class Standard < ApplicationRecord
  has_many :resource_standards, dependent: :destroy
  has_many :resources, through: :resource_standards

  validates :name, presence: true

  # NOTE: #954 - to be removed
  scope :by_grade, ->(grade) { by_grades [grade] }
  # NOTE: #954 - to be removed
  scope :by_grades, lambda { |grades|
    joins(resource_standards: { resource: [:grades] })
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

# frozen_string_literal: true

class Author < ApplicationRecord
  has_many :resources
  has_many :curriculums, -> { distinct }, through: :resources
end

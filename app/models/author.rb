# frozen_string_literal: true

# == Schema Information
#
# Table name: authors
#
#  id         :integer          not null, primary key
#  name       :string
#  slug       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Author < ApplicationRecord
  has_many :resources
  has_many :curriculums, -> { distinct }, through: :resources
end

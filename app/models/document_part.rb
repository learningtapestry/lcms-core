# frozen_string_literal: true

class DocumentPart < ApplicationRecord
  belongs_to :renderer, polymorphic: true

  enum :context_type, { default: 0, gdoc: 1 }

  default_scope { active }

  scope :active, -> { where(active: true) }
  scope :general, -> { where(optional: false) }
  scope :optional, -> { where(optional: true) }
end

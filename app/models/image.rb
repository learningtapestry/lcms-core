# frozen_string_literal: true

# == Schema Information
#
# Table name: images
#
#  id         :bigint           not null, primary key
#  alt_text   :text
#  caption    :text
#  credit     :text
#  file_url   :string           not null
#  identifier :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_images_on_identifier  (identifier) UNIQUE
#
class Image < ApplicationRecord
  URL_RE = %r{\Ahttps?://\S+\z}i

  before_validation { self.identifier = identifier.to_s.strip.downcase.presence }

  validates :identifier, presence: true, uniqueness: true
  validates :file_url, presence: true, format: { with: URL_RE }

  scope :search_by_identifier, ->(term) { where("identifier ILIKE ?", "%#{sanitize_sql_like(term.to_s.strip)}%") }

  def self.find_by_identifier(identifier)
    find_by(identifier: identifier.to_s.strip.downcase)
  end
end

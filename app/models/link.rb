# frozen_string_literal: true

# == Schema Information
#
# Table name: links
#
#  id         :bigint           not null, primary key
#  identifier :string           not null
#  text       :text
#  url        :text             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_links_on_identifier  (identifier) UNIQUE
#
class Link < ApplicationRecord
  URL_RE = %r{\Ahttps?://\S+\z}i

  before_validation { self.identifier = identifier.to_s.strip.downcase.presence }

  validates :identifier, presence: true, uniqueness: true
  validates :url, presence: true, format: { with: URL_RE }

  scope :search_by_identifier, ->(term) { where("identifier ILIKE ?", "%#{sanitize_sql_like(term.to_s.strip)}%") }

  def self.find_by_identifier(identifier)
    find_by(identifier: identifier.to_s.strip.downcase)
  end

  # What the tag renders as the link: the sheet's text, else the URL itself.
  def label
    text.presence || url
  end
end

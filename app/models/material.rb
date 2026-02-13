# frozen_string_literal: true

require "pg_search"

class Material < ApplicationRecord
  include Filterable
  include PgSearch::Model
  include Partable

  validates :file_id, presence: true
  validates :identifier, uniqueness: true

  has_many :document_parts, as: :renderer, dependent: :delete_all

  store_accessor :metadata

  pg_search_scope :search_identifier, against: :identifier, using: { tsearch: { prefix: true } }

  scope :where_metadata, ->(hash) { where("materials.metadata @> ?", hash.to_json) }
  scope :where_metadata_like, ->(key, val) { where("materials.metadata ->> ? ILIKE ?", key, "%#{val}%") }
  scope :where_metadata_not, ->(hash) { where.not("materials.metadata @> ?", hash.to_json) }

  def self.where_metadata_any_of(conditions)
    condition = Array.new(conditions.size, "materials.metadata @> ?").join(" or ")
    where(condition, *conditions.map(&:to_json))
  end

  def file_url
    "https://docs.google.com/document/d/#{file_id}"
  end
end

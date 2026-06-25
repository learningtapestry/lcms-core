# frozen_string_literal: true

# == Schema Information
#
# Table name: documents
#
#  id                :integer          not null, primary key
#  active            :boolean          default(TRUE), not null
#  activity_metadata :jsonb
#  agenda_metadata   :jsonb
#  css_styles        :text
#  last_author_email :string
#  last_author_name  :string
#  last_modified_at  :datetime
#  links             :jsonb            not null
#  metadata          :jsonb            not null
#  name              :string
#  original_content  :text
#  preview_links     :jsonb
#  reimported        :boolean          default(TRUE), not null
#  reimported_at     :datetime
#  sections_metadata :jsonb
#  version           :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  file_id           :string
#  resource_id       :integer
#
# Indexes
#
#  index_documents_on_file_id      (file_id)
#  index_documents_on_metadata     (metadata) USING gin
#  index_documents_on_resource_id  (resource_id)
#
class Document < ApplicationRecord
  include Filterable
  include Partable
  include PdfRenderable

  GOOGLE_URL_PREFIX = "https://docs.google.com/document/d"

  belongs_to :resource, optional: true
  has_many :document_parts, as: :renderer, dependent: :delete_all

  after_destroy :destroy_connected_resource

  before_save :clean_curriculum_metadata
  before_save :set_resource_from_metadata

  scope :actives, -> { where(active: true) }
  scope :inactives, -> { where(active: false) }

  scope :failed, -> { where(reimported: false) }

  scope :where_metadata, ->(key, val) { where("documents.metadata ->> ? = ?", key, val.to_s) }

  scope :order_by_curriculum, lambda {
    select("documents.*, resources.hierarchical_position")
      .joins(:resource)
      .order("resources.hierarchical_position ASC")
  }

  scope :filter_by_term, lambda { |search_term|
    term = "%#{search_term}%"
    joins(:resource).where("resources.title ILIKE ? OR documents.name ILIKE ?", term, term)
  }

  scope :filter_by_subject, ->(subject) { where_metadata(:subject, subject) }
  scope :filter_by_grade, ->(grade) { where_metadata(:grade, grade) }
  scope :filter_by_unit, ->(unit) { where_metadata(:unit, unit) }
  scope :filter_by_section, ->(section) { where_metadata(:section, section) }

  scope :with_broken_materials, lambda {
    joins("LEFT JOIN jsonb_each(documents.links->'materials') AS links ON TRUE")
      .joins("LEFT JOIN materials as m on m.id = links.key::integer")
      .where("((links.value -> ?)::text IS NULL) OR ((links.value -> ?)::text IS NULL)", "gdoc", "url")
      .where.not("m.metadata ->> 'type' = ?", "pdf")
      .distinct
  }

  def activate!
    self.class.transaction do
      # de-active all other lessons for this resource
      self.class.where(resource_id:).where.not(id:).update_all(active: false)
      # activate this lesson. PS: use a simple SQL update, no callbacks
      update_columns(active: true)
    end
  end

  def assessment?
    resource&.assessment? || false
  end

  def file_url
    return unless file_id.present?

    "#{GOOGLE_URL_PREFIX}/#{file_id}"
  end

  def math?
    metadata["subject"].to_s.casecmp("math").zero?
  end

  def tmp_link(key)
    url = links[key]
    with_lock do
      reload.links.delete(key)
      update links:
    end
    url
  end

  private

  def clean_curriculum_metadata
    return unless metadata.present?

    metadata["subject"] = metadata["subject"]&.downcase
  end

  def destroy_connected_resource
    resource&.destroy if active?
  end

  def set_resource_from_metadata
    return unless metadata.present?

    resource = DocTemplate.metadata_context.new(metadata).find_or_create_resource

    self.resource_id = resource.id
  end
end

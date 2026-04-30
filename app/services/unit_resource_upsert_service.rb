# frozen_string_literal: true

class UnitResourceUpsertService
  def self.call(...)
    new(...).call
  end

  def initialize(metadata:, source_link_data: {})
    @metadata = metadata.with_indifferent_access
    @source_link_data = source_link_data.deep_stringify_keys
  end

  def call
    ApplicationRecord.transaction do
      resource = context.new(context_metadata).find_or_create_resource
      resource.update!(
        description: description_summary,
        links: resource.links.deep_merge(source_link_data),
        metadata: resource.metadata.deep_merge(resource_metadata),
        short_title: short_title,
        title: title
      )
      resource
    end
  end

  private

  attr_reader :metadata, :source_link_data

  def context
    DocTemplate.config.dig("metadata", "context").constantize
  end

  def context_metadata
    {
      description: description_summary,
      grade: metadata[:grade],
      subject: metadata[:subject],
      title:,
      unit: short_title
    }
  end

  def description_summary
    @description_summary ||= DocTemplate.sanitizer.strip_html_element(metadata[:description])
  end

  def resource_metadata
    metadata
      .to_h
      .stringify_keys
      .merge("unit" => short_title)
      .reject { |_key, value| value.blank? }
  end

  def short_title
    metadata[:unit_id]
  end

  def title
    metadata[:unit_title].presence || short_title
  end
end

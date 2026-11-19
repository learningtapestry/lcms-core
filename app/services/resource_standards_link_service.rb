# frozen_string_literal: true

#
# Links lesson resources to the standards their lesson lists in its metadata
# (METADATA_FIELDS; codes separated by commas, semicolons or line breaks).
# Codes are matched by Standard.find_by_code, preferring the lesson's
# subject; codes with no matching standard are skipped and returned, so the
# lesson import can warn about them. A resource's links are replaced each
# time, so they always reflect the current lesson and standards sheet.
#
# Runs after a lesson is built (DocumentBuildService) and after the standards
# sheet is imported (StandardsImportService), so either order works.
#
# Clients whose lessons list standards under another row (e.g.
# "building-towards") override METADATA_FIELDS or `.codes_for`.
#
class ResourceStandardsLinkService
  METADATA_FIELDS = %w(standards).freeze
  SPLIT_REGEX = DocTemplate::Tables::Base::SPLIT_REGEX

  # Re-links every resource that has an active lesson.
  #
  # @return [Integer] number of resources processed
  def self.call_all
    Resource.where(id: Resource.with_documents.select(:id)).find_each.count { !call(it).nil? }
  end

  #
  # @param [Resource, nil] resource
  # @return [Array<String>, nil] the lesson's codes that match no standard, or
  #   nil when the resource has no lesson to link from
  #
  def self.call(resource)
    metadata = resource&.document&.metadata
    return if metadata.nil?

    unknown = []
    ids = codes_for(metadata).filter_map do |code|
      standard = Standard.find_by_code(code, subject: metadata["subject"])
      unknown << code if standard.nil?
      standard&.id
    end
    resource.standard_ids = ids.uniq
    unknown
  end

  #
  # @param [Hash] metadata lesson metadata
  # @return [Array<String>] standard codes, without blanks or duplicates
  #
  def self.codes_for(metadata)
    self::METADATA_FIELDS
      .flat_map { metadata[it].to_s.split(SPLIT_REGEX) }
      .map(&:squish).compact_blank.uniq(&:downcase)
  end
end

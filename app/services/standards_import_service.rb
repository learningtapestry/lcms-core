# frozen_string_literal: true

#
# Imports the standards spreadsheet (a Google Sheet) that standard tags and
# resource links resolve against. Columns are matched by header, ignoring
# case, spacing and punctuation:
#
#   Code        - required; the standard's code, e.g. "RL.2.2" (also
#                 "Standard Code", "Identifier", "Standard", "Name")
#   Description - required column; the standard's text (also "Text")
#   Subject     - optional; a subject key or name ("math" or "Mathematics")
#   Grades, Alt Names - optional; comma- or semicolon-separated lists
#   Label       - optional; short display label (also "Visual Identifier")
#
# "Heading" is deliberately not mapped: clients use it for different things
# (an emphasis such as "Practice Standards", or a domain). Map it in a
# subclass's COLUMNS.
#
# Unlike images and URLs, standards are synced in place rather than replaced:
# a row updates the standard with the same subject and code (ignoring case)
# and new rows are added. Standards missing from the sheet are removed only
# within the subjects the sheet covers (#stale_scope), so separate sheets per
# subject can share the table. A sheet without a Subject column matches by
# code alone and covers every subject. A column missing from the sheet leaves
# that attribute as it was. Every lesson resource is then re-linked to the
# standards its lesson lists (ResourceStandardsLinkService).
#
# Clients extend the import with `.after_reimport_hook`, map other columns via
# COLUMNS / `#build`, and narrow removal further (e.g. by grade band) by
# overriding `#stale_scope`.
#
class StandardsImportService < SheetImportService
  SHEET_NAME = "standards"
  COLUMNS = {
    name: %w(code standardcode identifier standard name),
    description: %w(description text standardtext),
    subject: %w(subject),
    grades: %w(grades grade),
    alt_names: %w(altnames alternatenames aliases),
    label: %w(label visualidentifier identifiervisual)
  }.freeze
  REQUIRED_COLUMNS = %i(name description).freeze
  LIST_SEPARATOR = /\s*[,;]\s*/

  def self.call(url)
    super.tap { after_reimport_hook }
  end

  def self.after_reimport_hook; end

  private

  def model
    Standard
  end

  def build(values)
    values = values.merge(subject: subject_key(values[:subject])) if values.key?(:subject)
    %i(grades alt_names).each do |list|
      values[list] = values[list].to_s.split(LIST_SEPARATOR).compact_blank if values.key?(list)
    end
    Standard.new(**values)
  end

  def key_for(record)
    code = record.name.to_s.downcase
    subjects_in_sheet? ? [record.subject, code] : code
  end

  def key_attribute
    :name
  end

  def write(records)
    # Newest first, so with a code-only key the oldest standard wins a clash.
    existing = Standard.order(id: :desc).index_by { key_for(it) }
    kept_ids = records.map do |record|
      standard = existing[key_for(record)] || Standard.new
      standard.update!(record.attributes.slice(*imported_attributes.map(&:to_s)))
      standard.id
    end
    stale_scope(records).where.not(id: kept_ids).destroy_all
    ResourceStandardsLinkService.call_all
  end

  # Standards this sheet is responsible for: those missing from it are
  # removed. By default, every standard in the subjects the sheet's rows use
  # (a blank subject counting as one), or all of them when the sheet has no
  # Subject column.
  #
  # @param [Array<Standard>] records the sheet's rows
  # @return [ActiveRecord::Relation<Standard>]
  def stale_scope(records)
    return Standard.all unless subjects_in_sheet?

    Standard.where(subject: records.map(&:subject).uniq)
  end

  def subjects_in_sheet?
    imported_attributes.include?(:subject)
  end

  # "Mathematics" -> "math"; an unknown subject is kept as written.
  def subject_key(value)
    return if value.blank?

    SUBJECTS.find { |_key, name| name.casecmp?(value) }&.first || value
  end
end

# frozen_string_literal: true

# == Schema Information
#
# Table name: standards
#
#  id          :integer          not null, primary key
#  alt_names   :text             default([]), not null, is an Array
#  course      :string
#  description :string
#  domain      :string
#  emphasis    :string
#  grades      :text             default([]), not null, is an Array
#  label       :string
#  name        :string           not null
#  strand      :string
#  subject     :string
#  synonyms    :text             default([]), is an Array
#  created_at  :datetime
#  updated_at  :datetime
#
# Indexes
#
#  index_standards_on_name                    (name)
#  index_standards_on_subject                 (subject)
#  index_standards_on_subject_and_lower_name  (subject, lower((name)::text)) UNIQUE
#
class Standard < ApplicationRecord
  has_many :resource_standards, dependent: :destroy
  has_many :resources, through: :resource_standards

  # `name` is the standard's code (e.g. "RL.2.2"), unique within a subject
  # regardless of case (see StandardsImportService).
  normalizes :name, with: ->(name) { name.squish }
  normalizes :subject, with: ->(subject) { subject.strip.downcase.presence }

  validates :name, presence: true, uniqueness: { scope: :subject, case_sensitive: false }

  # A subject written in front of a code, as in "ELA.RL.2.2" ("ela" is not in
  # core's SUBJECTS but is how ELA codes are commonly prefixed).
  CODE_SUBJECT_PREFIX = /\A(?:#{(SUBJECTS.keys + %w(ela)).uniq.map { Regexp.escape(it) }.join('|')})\./

  # Admin search: codes or alt names containing +name+.
  def self.search_by_name(name)
    where("name ILIKE :q OR alt_names::text ILIKE :q", q: "%#{sanitize_sql_like(name.to_s.strip)}%").order(:id)
  end

  #
  # The standard whose code or alt name is exactly +code+, ignoring case and
  # spacing. A code match beats an alt-name match, and a standard in
  # +subject+ beats one in another subject. A code with a subject prefix
  # ("ELA.RL.2.2") falls back to the code without it ("RL.2.2").
  #
  # @param [String] code e.g. "RL.2.2"
  # @param [String, nil] subject e.g. "ela"
  # @return [Standard, nil]
  #
  def self.find_by_code(code, subject: nil)
    code = code.to_s.squish.downcase
    return if code.blank?

    subject = subject.to_s.strip.downcase.presence
    unprefixed = code.sub(CODE_SUBJECT_PREFIX, "")
    [code, unprefixed].uniq.each do |candidate|
      match = where(<<~SQL.squish, code: candidate)
        lower(name) = :code OR EXISTS (SELECT 1 FROM unnest(alt_names) alt WHERE lower(alt) = :code)
      SQL
        .min_by { |standard| [standard.name.casecmp?(candidate) ? 0 : 1, standard.subject == subject ? 0 : 1, standard.id] }
      return match if match
    end
    nil
  end
end

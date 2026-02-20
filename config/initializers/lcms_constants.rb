# frozen_string_literal: true

BUNDLE_CONTENT_TYPES = %w(unit_bundle)

BUNDLE_S3_FOLDER = "bundles"

CONTENT_TYPES = %w(full tm sm).freeze

FLASH_MESSAGE_MAX_CHAR = 2048
FLASH_REDIS_PREFIX = "flash_key:"

GRADES = ["prekindergarten", "kindergarten", "grade 1", "grade 2", "grade 3",
          "grade 4", "grade 5", "grade 6", "grade 7", "grade 8", "grade 9",
          "grade 10", "grade 11", "grade 12"].freeze

GRADES_ABBR = %w(pk k 1 2 3 4 5 6 7 8 9 10 11 12).freeze

GRADES_COLLECTION = GRADES.map(&:capitalize).zip(GRADES_ABBR).freeze

HIERARCHY = %i(subject grade unit section lesson).freeze

MATERIAL_TYPES = {
  rubric: "rubric",
  tool: "tool",
  reference_guide: "reference_guide"
}.freeze

SUBJECTS = {
  math: "Mathematics"
}.with_indifferent_access.freeze
SUBJECTS_SHORT = {
  math: "MATH"
}.with_indifferent_access.freeze
SUBJECT_DEFAULT = "math"

SETTINGS = {
  appearance: {
    header_bg_color: :color,
    header_text_color: :color,
    header_dropdown_bg_color: :color,
    header_active_item_color: :color,
    header_logo: :image
  }
}.freeze

SETTINGS_DEFAULTS = {
  appearance: {
    header_bg_color: "#f8f9fa",
    header_text_color: "#000000",
    header_dropdown_bg_color: "#ffffff",
    header_active_item_color: "#0d6efd",
    header_logo: nil
  }
}.freeze

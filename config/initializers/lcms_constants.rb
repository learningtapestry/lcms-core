# frozen_string_literal: true

BUNDLE_S3_FOLDER = "bundles"

CONTENT_TYPES = %w(full tm sm).freeze

FLASH_MESSAGE_MAX_CHAR = 2048
FLASH_REDIS_PREFIX = "flash_key:"

HIERARCHY = %i(subject grade module unit lesson).freeze

MATERIAL_TYPES = {
  rubric: "rubric",
  tool: "tool",
  reference_guide: "reference_guide"
}.freeze

SUBJECTS = {
  ela: "English Language Arts",
  math: "Mathematics"
}.with_indifferent_access.freeze
SUBJECTS_SHORT = {
  ela: "ELA",
  math: "MATH"
}.with_indifferent_access.freeze
SUBJECT_DEFAULT = "ela"

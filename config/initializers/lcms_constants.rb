# frozen_string_literal: true

SUBJECTS = {
  ela: "English Language Arts",
  math: "Mathematics"
}.with_indifferent_access.freeze
SUBJECTS_SHORT = {
  ela: "ELA",
  math: "MATH"
}.with_indifferent_access.freeze
SUBJECT_DEFAULT = "ela"

HIERARCHY = %i(subject grade module unit lesson).freeze

PDF_SUBTITLES = { full: "", sm: "_student_materials", tm: "_teacher_materials" }.freeze

FLASH_MESSAGE_MAX_CHAR = 2048
FLASH_REDIS_PREFIX = "flash_key:"

MATERIAL_TYPES = {
  rubric: "rubric",
  tool: "tool",
  reference_guide: "reference_guide"
}.freeze

# Bundles
SB_MATERIALS = %i(rubric tool).freeze
TB_MATERIALS = %i(rubric tool reference_guide).freeze

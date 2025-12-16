# frozen_string_literal: true

# Constand moved from Resource model
SUBJECTS = %w(ela math).freeze
SUBJECT_DEFAULT = "ela"
HIERARCHY = %i(subject grade module unit lesson).freeze

# Moved from DocumentPresenter
PDF_SUBTITLES = { full: "", sm: "_student_materials", tm: "_teacher_materials" }.freeze
SUBJECT_FULL  = { "ela" => "ELA", "math" => "Math" }.freeze
TOPIC_FULL    = { "ela" => "Unit", "math" => "Topic" }.freeze
TOPIC_SHORT   = { "ela" => "U", "math" => "T" }.freeze

# Constants migrated from lcms-engine gem
FLASH_MESSAGE_MAX_CHAR = 2048
FLASH_REDIS_PREFIX = "flash_key:"

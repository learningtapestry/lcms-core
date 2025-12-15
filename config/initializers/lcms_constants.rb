# frozen_string_literal: true

# Constand moved from Resource model
SUBJECTS = %w(ela math).freeze
SUBJECT_DEFAULT = "ela"
HIERARCHY = %i(subject grade module unit lesson).freeze

# Constants migrated from lcms-engine gem
FLASH_MESSAGE_MAX_CHAR = 2048
FLASH_REDIS_PREFIX = "flash_key:"

# frozen_string_literal: true

# Indicates whether S3 access is blocked, based on the environment variable `AWS_S3_BLOCK`.
AWS_S3_BLOCK = ENV.fetch("AWS_S3_BLOCK", "false").in?(%w(true 1))

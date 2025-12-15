# frozen_string_literal: true

# WickedPdf configuration for PDF generation
# Uses wkhtmltopdf binary to convert HTML to PDF

WickedPdf.configure do |config|
  # Path to wkhtmltopdf binary
  # Can be overridden with WKHTMLTOPDF_PATH environment variable
  # In Docker, this will be installed via wkhtmltopdf-binary gem
  config.exe_path = ENV.fetch("WKHTMLTOPDF_PATH", "/usr/local/bin/wkhtmltopdf")
end

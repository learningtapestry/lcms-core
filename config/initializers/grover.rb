# frozen_string_literal: true

Grover.configure do |config|
  config.options = {
    executable_path: ENV.fetch("GROVER_EXECUTABLE_PATH", nil),
    wait_until: "networkidle0",
    timeout: ENV.fetch("PUPPETEER_TIMEOUT", 0).to_i
  }
end

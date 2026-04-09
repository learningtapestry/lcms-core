# frozen_string_literal: true

Grover.configure do |config|
  config.options = {
    executable_path: ENV.fetch("GROVER_EXECUTABLE_PATH", nil),
    wait_until: "networkidle0",
    timeout: ENV.fetch("PUPPETEER_TIMEOUT", 0).to_i,
    # Disable Chrome sandbox for server environments (e.g., Cloud66) where Chrome
    # runs under a system user without a proper user namespace setup.
    # Set GROVER_NO_SANDBOX=true in environment variables to enable.
    launch_args: ENV["GROVER_NO_SANDBOX"] == "true" ? ["--no-sandbox", "--disable-setuid-sandbox"] : []
  }
end

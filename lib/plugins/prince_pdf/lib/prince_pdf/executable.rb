# frozen_string_literal: true

require "open3"

module PrincePdf
  #
  # PrinceXML binary discovery and invocation.
  #
  # Uses Open3 to shell out to the `prince` command. Path is configurable
  # via PRINCE_EXECUTABLE_PATH; otherwise the default `prince` resolves
  # against $PATH.
  #
  # `present?` is cached after the first probe so the registry's repeated
  # `available?` calls don't fork a subprocess every time. Tests use
  # `reset!` to clear the cache between scenarios.
  #
  module Executable
    DEFAULT_BINARY = "prince"

    class NonZeroExit < StandardError; end

    class << self
      def path
        ENV.fetch("PRINCE_EXECUTABLE_PATH", DEFAULT_BINARY)
      end

      def present?
        return @present if defined?(@present)

        @present = probe
      end

      def version
        stdout, _stderr, status = Open3.capture3(path, "--version")
        status.success? ? stdout.lines.first&.strip : nil
      rescue Errno::ENOENT
        nil
      end

      #
      # Run prince with the given arg list. HTML on stdin, PDF bytes on stdout.
      # Raises NonZeroExit with stderr if prince exits non-zero.
      #
      def run(args, stdin:)
        stdout, stderr, status = Open3.capture3(path, *args, stdin_data: stdin)
        raise NonZeroExit, stderr unless status.success?

        stdout
      end

      def reset!
        remove_instance_variable(:@present) if defined?(@present)
      end

      private

      def probe
        _stdout, _stderr, status = Open3.capture3(path, "--version")
        status.success?
      rescue Errno::ENOENT
        false
      end
    end
  end
end

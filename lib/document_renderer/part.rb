# frozen_string_literal: true

module DocumentRenderer
  # Recursively renders document parts by replacing placeholders with their content.
  #
  # Placeholders follow the pattern `{{part_name}}` and are resolved using
  # a parts index that maps placeholders to their content and metadata.
  #
  # @example
  #   options = {
  #     parts_index: { "{{intro}}" => { content: "Hello", optional: false } },
  #     with_optional: false
  #   }
  #   DocumentRenderer::Part.call("Start {{intro}} End", options)
  #   # => "Start Hello End"
  #
  class Part
    # Regex pattern to match part placeholders in the format {{part_name}}
    PART_RE = /{{[^}]+}}/

    class << self
      # Replaces all part placeholders in the content with their rendered values.
      #
      # @param content [String] the content containing placeholders to replace
      # @param options [Hash] rendering options
      # @option options [Hash] :parts_index mapping of placeholders to part data
      # @option options [Boolean] :with_optional whether to render optional parts
      # @return [String] content with all placeholders replaced
      def call(content, options)
        content.gsub(PART_RE) do |placeholder|
          next unless placeholder
          next unless (part = options[:parts_index][placeholder])
          next unless (subpart = part[:content])
          next unless should_render?(part, include_optional: options[:with_optional])

          call subpart.to_s, options
        end
      end

      private

      # Determines whether a part should be rendered based on its optional flag.
      #
      # @param part [Hash] the part data containing :optional flag
      # @param include_optional [Boolean] whether to include optional parts
      # @return [Boolean] true if the part should be rendered
      def should_render?(part, include_optional: false)
        return true unless part[:optional]

        include_optional
      end
    end
  end
end

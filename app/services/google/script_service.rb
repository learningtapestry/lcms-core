# frozen_string_literal: true

# TODO: Extract base functionality into `lt-google-api` gem
module Google
  class ScriptService
    include GoogleCredentials

    SCRIPT_ID = ENV.fetch("GOOGLE_APPLICATION_SCRIPT_ID", "PLEASE SET UP SCRIPT ID")
    SCRIPT_FUNCTION = ENV.fetch("GOOGLE_APPLICATION_SCRIPT_FUNCTION", "postProcessing")

    def initialize(document)
      @document = document
    end

    #
    # @param [String] id Google Document identifier
    #
    def execute(id)
      request = ::Google::Apis::ScriptV1::ExecutionRequest.new(
        function: SCRIPT_FUNCTION,
        parameters: [id, gdoc_template_id, *Array.wrap(parameters)]
      )
      response = service.run_script(SCRIPT_ID, request)

      raise_error(id, response) if response.blank? || response.error
    end

    private

    attr_reader :document

    def ensure_not_nil_params_for(data)
      data&.map { |row| row.map { _1 || "" } }
    end

    # Returns Google Doc template ID based on document orientation.
    #
    # ENV variables:
    #   GOOGLE_APPLICATION_TEMPLATE_PORTRAIT  - template for portrait orientation (default)
    #   GOOGLE_APPLICATION_TEMPLATE_LANDSCAPE - template for landscape orientation
    #
    # @return [String] Google Doc template ID
    def gdoc_template_id
      orientation = document&.orientation || "portrait"

      ENV.fetch("GOOGLE_APPLICATION_TEMPLATE_#{orientation.upcase}")
    end


    # Parameters passed to Google Apps Script for document post-processing.
    #
    # Structure:
    #   [0] Boolean - true if landscape orientation
    #   [1..n] gdoc_footer rows - placeholder/value pairs for footer replacement
    #   [n+1..m] gdoc_header rows - placeholder/value pairs for header replacement
    #
    # gdoc_footer format (from DocumentPresenter#gdoc_footer):
    #   [["{attribution}"], [cc_attribution || "Copyright attribution here"]]
    #
    # gdoc_header format (from DocumentPresenter#gdoc_header):
    #   [["{title}"], [title]]
    #
    # @return [Array]
    def parameters
      [
        document.orientation&.downcase == "landscape",
        *ensure_not_nil_params_for(document.gdoc_footer),
        *ensure_not_nil_params_for(document.gdoc_header)
      ].compact
    end

    def raise_error(id, response)
      msg = "Error with document: #{id}\n"

      if response.blank?
        msg += "Script error message: Empty response from Google Apps Script\n"
      else
        error = response.error.details[0]
        msg += "Script error message: #{error['errorMessage']}\n"

        if error["scriptStackTraceElements"]
          msg += "Script error stacktrace:"
          error["scriptStackTraceElements"].each do |trace|
            msg += "\t#{trace['function']}: #{trace['lineNumber']}"
          end
        end
      end

      raise ::Google::Apis::Error, msg
    end

    def service
      @service ||=
        begin
          service = ::Google::Apis::ScriptV1::ScriptService.new
          service.authorization = google_credentials
          service
        end
    end
  end
end

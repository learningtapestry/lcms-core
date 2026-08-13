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
        parameters: [id, gdoc_template_id, *Array.wrap(parameters)],
        dev_mode: dev_mode?
      )
      response = service.run_script(SCRIPT_ID, request)

      raise_error(id, response) if response.blank? || response.error
    end

    private

    attr_reader :document

    # When true, scripts.run executes the most recently SAVED (HEAD) version of
    # the Apps Script instead of the version pinned to the API Executable
    # deployment — so an editor Save is enough and no redeploy / version bump is
    # needed. Requires the authenticated identity to have edit access to the
    # script. Keep false in production (run the stable, deployed version); set
    # GOOGLE_APPLICATION_SCRIPT_DEV_MODE=true on QA/staging to iterate on
    # config/scripts/Code.gs without redeploying each change. Read per call
    # (not memoized) so flipping the env var takes effect without a restart.
    def dev_mode?
      ENV.fetch("GOOGLE_APPLICATION_SCRIPT_DEV_MODE", "false") == "true"
    end

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
    # Positional — must line up with config/scripts/Code.gs#postProcessing(
    #   documentId, templateId, isLandscape,
    #   footerPatterns, footerReplaceTexts, headerPatterns, headerReplaceTexts,
    #   gradeColors, brandmarkData).
    #
    # Structure (after documentId/templateId, prepended in #execute):
    #   [0] Boolean            - true if landscape orientation
    #   [1] footerPatterns     - Array of all footer placeholders
    #   [2] footerReplaceTexts - Array of footer values (parallel to [1])
    #   [3] headerPatterns     - Array of all header placeholders
    #   [4] headerReplaceTexts - Array of header values (parallel to [3])
    #   [5] gradeColors        - reserved positional slot (unused; kept so the
    #                            brandmark data lands on postProcessing's 9th arg)
    #   [6] brandmarkData      - base64 data URI of the logo, decoded + inserted
    #                            by the script into the header's {brandmark_url}
    #                            placeholder (inline bytes, so the script needs
    #                            no UrlFetchApp / script.external_request scope)
    #
    # So gdoc_footer / gdoc_header MUST each be exactly [patterns, values] —
    # two parallel arrays, NOT a list of [placeholder, value] pairs. The Apps
    # Script loops replaceText(patterns[i], values[i]) over its footer/header.
    #
    # gdoc_footer (DocumentPresenter):
    #   [["{copyright}", "{course}", "{unit_lesson}"], [copyright, course, unit_lesson]]
    # gdoc_header (DocumentPresenter):
    #   [["{title}", "{unit_title}", "{lesson_type}", "{estimated_time}"],
    #    [title, unit_title, lesson_type, estimated_time]]
    #   (MaterialPresenter uses the single [["{attribution}"], [value]] shape.)
    #
    # @return [Array]
    def parameters
      [
        document.orientation&.downcase == "landscape",
        *ensure_not_nil_params_for(document.gdoc_footer),
        *ensure_not_nil_params_for(document.gdoc_header),
        [], # gradeColors — reserved positional slot before brandmarkData
        document.try(:brandmark_data_uri).to_s
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

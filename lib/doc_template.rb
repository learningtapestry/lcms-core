# frozen_string_literal: true

module DocTemplate
  FULL_TAG = /\[([^\]:\s]*)?\s*:?\s*([^\]]*?)?\]/mo
  START_TAG = '\[[^\]]*'

  STARTTAG_XPATH = 'span[contains(., "[")]'
  ENDTAG_XPATH = 'span[contains(., "]")]'

  class << self
    def config
      @config ||= load_config
    end

    def reload!
      @config = nil
      @sanitizer = nil
      @context_types = nil
      @document_contexts = nil
      @material_contexts = nil
      @metadata_context = nil
      @metadata_service = nil
      @document_query = nil
      @material_query = nil
    end

    def context_types
      @context_types ||= Array.wrap(config[:contexts])
    end

    def document_contexts
      @document_contexts ||= Array.wrap(config[:document_contexts])
    end

    def material_contexts
      @material_contexts ||= Array.wrap(config[:material_contexts])
    end

    def sanitizer
      @sanitizer ||= config[:sanitizer].constantize
    end

    def metadata_context
      @metadata_context ||= config.dig(:metadata, :context).constantize
    end

    def metadata_service
      @metadata_service ||= config.dig(:metadata, :service).constantize
    end

    def document_query
      @document_query ||= config.dig(:queries, :document).constantize
    end

    def material_query
      @material_query ||= config.dig(:queries, :material).constantize
    end

    private

    def load_config
      Settings.get(:doc_template, include_defaults: true) || {}
    rescue ActiveRecord::StatementInvalid,
           ActiveRecord::NoDatabaseError,
           ActiveRecord::ConnectionNotEstablished
      Settings::DEFAULTS[:doc_template]
    end
  end
end

require "doc_template/template"
require "doc_template/document"
require "doc_template/tags"
require "doc_template/xpath_functions"

Dir["#{__dir__}/doc_template/validators/*.rb"].each { require _1 }
Dir["#{__dir__}/doc_template/tables/*.rb"].each { require _1 }
Dir["#{__dir__}/doc_template/tags/*.rb"].each { require _1 }
Dir["#{__dir__}/doc_template/objects/*.rb"].each { require _1 }

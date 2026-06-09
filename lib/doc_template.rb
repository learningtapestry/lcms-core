# frozen_string_literal: true

module DocTemplate
  FULL_TAG = /\[([^\]:\s]*)?\s*:?\s*([^\]]*?)?\]/mo
  START_TAG = '\[[^\]]*'

  STARTTAG_XPATH = 'span[contains(., "[")]'
  ENDTAG_XPATH = 'span[contains(., "]")]'

  class << self
    def config
      @config || load_config
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
      cached(:context_types) { |c| Array.wrap(c[:contexts]) }
    end

    def document_contexts
      cached(:document_contexts) { |c| Array.wrap(c[:document_contexts]) }
    end

    def material_contexts
      cached(:material_contexts) { |c| Array.wrap(c[:material_contexts]) }
    end

    def sanitizer
      cached(:sanitizer) { |c| c[:sanitizer].constantize }
    end

    def metadata_context
      cached(:metadata_context) { |c| c.dig(:metadata, :context).constantize }
    end

    def metadata_service
      cached(:metadata_service) { |c| c.dig(:metadata, :service).constantize }
    end

    def document_query
      cached(:document_query) { |c| c.dig(:queries, :document).constantize }
    end

    def material_query
      cached(:material_query) { |c| c.dig(:queries, :material).constantize }
    end

    private

    # Reads the doc_template setting and memoizes it (@config) only on a
    # healthy DB read. On a transient error (e.g. assets:precompile with no
    # DB, or a brief outage) it returns the shipped defaults for THIS call
    # WITHOUT memoizing, so a later call retries the DB instead of pinning
    # defaults for the whole process lifetime.
    def load_config
      @config = Settings.get(:doc_template, include_defaults: true) || {}
    rescue ActiveRecord::StatementInvalid,
           ActiveRecord::NoDatabaseError,
           ActiveRecord::ConnectionNotEstablished
      Settings::DEFAULTS[:doc_template]
    end

    # Memoizes a config-derived value, but only when `config` came from a
    # healthy read (@config set). During a degraded read it recomputes from
    # the defaults each call so the value is never pinned to a fallback.
    def cached(name)
      ivar = "@#{name}"
      existing = instance_variable_get(ivar)
      return existing if existing

      value = yield(config)
      instance_variable_set(ivar, value) if @config
      value
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

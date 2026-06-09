# frozen_string_literal: true

module DocTemplate
  FULL_TAG = /\[([^\]:\s]*)?\s*:?\s*([^\]]*?)?\]/mo
  START_TAG = '\[[^\]]*'

  STARTTAG_XPATH = 'span[contains(., "[")]'
  ENDTAG_XPATH = 'span[contains(., "]")]'

  class << self
    def config
      store[:config] ||= load_config
    end

    # Clears the per-request memo. Rails resets it automatically between
    # requests/jobs; specs (and anything that edits doc_template mid-process and
    # wants the change applied immediately) call this to force a fresh read.
    def reload!
      Current.doc_template = nil
    end

    def context_types
      store[:context_types] ||= Array.wrap(config[:contexts])
    end

    def document_contexts
      store[:document_contexts] ||= Array.wrap(config[:document_contexts])
    end

    def material_contexts
      store[:material_contexts] ||= Array.wrap(config[:material_contexts])
    end

    def sanitizer
      store[:sanitizer] ||= config[:sanitizer].constantize
    end

    def metadata_context
      store[:metadata_context] ||= config.dig(:metadata, :context).constantize
    end

    def metadata_service
      store[:metadata_service] ||= config.dig(:metadata, :service).constantize
    end

    def document_query
      store[:document_query] ||= config.dig(:queries, :document).constantize
    end

    def material_query
      store[:material_query] ||= config.dig(:queries, :material).constantize
    end

    private

    # Per-request / per-job memo (see Current). One Settings read serves every
    # hot-loop accessor within a unit of work, and the next request/job re-reads
    # — so an admin edit to the doc_template setting applies without a restart.
    def store
      Current.doc_template ||= {}
    end

    # The doc_template setting merged with the shipped defaults. On a transient
    # error (e.g. assets:precompile with no DB, or a brief outage) it returns the
    # shipped defaults; because the memo is per-request the fallback is never
    # pinned beyond the current unit of work.
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

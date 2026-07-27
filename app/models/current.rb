# frozen_string_literal: true

# Per-request / per-job state, reset by Rails before and after each request and
# each Active Job execution.
class Current < ActiveSupport::CurrentAttributes
  # Memo for DocTemplate's resolved config + derived (constantized) values. Hot
  # accessors (sanitizer, context_types, ...) read the cached Settings value
  # once per unit of work, and a settings edit is picked up on the next
  # request/job without a process restart (the store is reset between them).
  attribute :doc_template

  # Per-render memo of `[material: id]` token lookups (downcased identifier =>
  # Material or nil), so a lesson's many activity Materials lines resolve
  # against one query set instead of one per activity. See
  # DocTemplate::Tags::MaterialTokens.lookup.
  attribute :material_tokens

  # Per-render memo of inlined asset data URIs (url => data-URI String or nil),
  # so repeated blocking remote fetches of the same asset (e.g. a shared callout
  # icon) happen at most once per render. See AssetHelper.inline_data_uri.
  attribute :inline_data_uris
end

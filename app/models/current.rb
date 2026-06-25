# frozen_string_literal: true

# Per-request / per-job state, reset by Rails before and after each request and
# each Active Job execution.
class Current < ActiveSupport::CurrentAttributes
  # Memo for DocTemplate's resolved config + derived (constantized) values. Hot
  # accessors (sanitizer, context_types, ...) read the cached Settings value
  # once per unit of work, and a settings edit is picked up on the next
  # request/job without a process restart (the store is reset between them).
  attribute :doc_template
end

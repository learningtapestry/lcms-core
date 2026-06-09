# frozen_string_literal: true

class SettingsForm
  # A single SETTINGS group. The save flow is two-phase so a rejected submit has
  # no side effects: `prepare` stages the submitted input (building/validating
  # models) WITHOUT writing anything, then — only if the whole form is valid —
  # `commit` persists. The controller and SettingsForm treat every group through
  # this uniform interface instead of inspecting the schema shape.
  class BaseGroup
    attr_reader :key

    def initialize(key)
      @key = key
    end

    def form?
      false
    end

    def valid?
      true
    end

    # Stage submitted params with no side effects (no DB writes, no uploads).
    def prepare(_params); end

    # Persist staged changes. Called only after the whole form validates.
    def commit; end
  end
end

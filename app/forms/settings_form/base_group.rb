# frozen_string_literal: true

class SettingsForm
  # A single SETTINGS group. Subclasses implement #apply (persist submitted
  # changes), #valid? and #reset; the controller and SettingsForm treat every
  # group through this uniform interface instead of inspecting the schema shape.
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
  end
end

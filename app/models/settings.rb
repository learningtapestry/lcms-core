# frozen_string_literal: true

module Lcms
  module Engine
    class Settings < ApplicationRecord
      class << self
        def [](key)
          settings.data[key.to_s]
        end

        def []=(key, value)
          new_settings = {}.tap { _1[key.to_s] = value } # steep:ignore
          settings.update data: settings.data.merge(new_settings)
        end

        private

        def settings
          last || create!(data: { editing_enabled: true })
        end
      end
    end
  end
end

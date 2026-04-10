# frozen_string_literal: true

module Types
  class JsonArray < ActiveModel::Type::Value
    def type = :json_array

    def cast(value)
      case value
      when Array then value
      when nil then []
      else Array(value)
      end
    end
  end
end

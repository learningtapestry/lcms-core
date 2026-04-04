# frozen_string_literal: true

module Types
  class JsonHash < ActiveModel::Type::Value
    def type = :json_hash

    def cast(value)
      case value
      when Hash then value
      when nil then {}
      else value.respond_to?(:to_h) ? value.to_h : {}
      end
    end
  end
end

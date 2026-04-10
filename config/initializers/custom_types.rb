# frozen_string_literal: true

require "types/json_array"
require "types/json_hash"

ActiveModel::Type.register(:json_array, Types::JsonArray)
ActiveModel::Type.register(:json_hash, Types::JsonHash)

# frozen_string_literal: true

class ResourceStandard < ApplicationRecord
  belongs_to :resource
  belongs_to :standard
end

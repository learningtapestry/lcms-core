# frozen_string_literal: true

# == Schema Information
#
# Table name: resource_standards
#
#  id          :integer          not null, primary key
#  created_at  :datetime
#  updated_at  :datetime
#  resource_id :integer
#  standard_id :integer
#
# Indexes
#
#  index_resource_standards_on_resource_id  (resource_id)
#  index_resource_standards_on_standard_id  (standard_id)
#
# Foreign Keys
#
#  fk_rails_...  (resource_id => resources.id)
#  fk_rails_...  (standard_id => standards.id)
#
class ResourceStandard < ApplicationRecord
  belongs_to :resource
  belongs_to :standard
end

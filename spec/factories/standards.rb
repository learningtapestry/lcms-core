# frozen_string_literal: true

# == Schema Information
#
# Table name: standards
#
#  id          :integer          not null, primary key
#  alt_names   :text             default([]), not null, is an Array
#  course      :string
#  description :string
#  domain      :string
#  emphasis    :string
#  grades      :text             default([]), not null, is an Array
#  label       :string
#  name        :string           not null
#  strand      :string
#  subject     :string
#  synonyms    :text             default([]), is an Array
#  created_at  :datetime
#  updated_at  :datetime
#
# Indexes
#
#  index_standards_on_name     (name)
#  index_standards_on_subject  (subject)
#
FactoryBot.define do
  factory :standard, class: Standard do
    subject { %w(ela math).sample }
    name { "name" }
  end
end

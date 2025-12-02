# frozen_string_literal: true

FactoryBot.define do
  factory :standard, class: Standard do
    subject { %w(ela math).sample }
    name { 'name' }
  end
end

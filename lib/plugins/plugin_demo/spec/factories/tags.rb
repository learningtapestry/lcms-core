# frozen_string_literal: true

FactoryBot.define do
  factory :plugin_demo_tag, class: PluginDemo::Tag do
    name { Faker::Lorem.words.join(" ") }
  end
end

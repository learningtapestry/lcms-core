# frozen_string_literal: true

FactoryBot.define do
  factory :plugin_demo_tagging, class: PluginDemo::Tagging do
    context { "tags" }
    tag { association :plugin_demo_tag }
    taggable { association :resource }
  end
end

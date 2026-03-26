# frozen_string_literal: true

require "acts-as-taggable-on"

module PluginDemo
  class Tag < ActsAsTaggableOn::Tag
    has_many :taggings, class_name: "PluginDemo::Tagging", foreign_key: :tag_id, dependent: :destroy
  end
end

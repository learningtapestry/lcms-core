# frozen_string_literal: true

require "acts-as-taggable-on"

module PluginDemo
  class Tagging < ActsAsTaggableOn::Tagging
    belongs_to :tag, class_name: "PluginDemo::Tag"
    belongs_to :taggable, polymorphic: true
    belongs_to :tagger, polymorphic: true, optional: true
  end
end

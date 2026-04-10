# frozen_string_literal: true

module PluginDemo
  # Tagging join model backed by the acts-as-taggable-on gem.
  #
  # Uses the default `taggings` table. This plugin owns the table — other plugins
  # that need tagging should declare plugin_demo as a dependency.
  class Tagging < ActsAsTaggableOn::Tagging
    belongs_to :tag, class_name: "PluginDemo::Tag"
    belongs_to :taggable, polymorphic: true
    belongs_to :tagger, polymorphic: true, optional: true
  end
end

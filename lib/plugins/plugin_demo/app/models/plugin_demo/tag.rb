# frozen_string_literal: true

module PluginDemo
  # Tag model backed by the acts-as-taggable-on gem.
  #
  # Uses the default `tags` table. This plugin owns the table — other plugins
  # that need tagging should declare plugin_demo as a dependency.
  class Tag < ActsAsTaggableOn::Tag
    has_many :taggings, class_name: "PluginDemo::Tagging", foreign_key: :tag_id, dependent: :destroy

    scope :where_context, ->(context) { joins(:taggings).where(taggings: { context: }) }
  end
end

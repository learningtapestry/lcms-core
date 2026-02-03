# frozen_string_literal: true

module PluginDemo
  # Service for working with tags
  #
  # Demonstrates how plugin services can interact with main application models.
  class TagService
    DEMO_TAG_NAME = "plugin-demo-tag"

    # Returns all tags ordered by name
    #
    # @return [ActiveRecord::Relation<Tag>]
    def all_tags
      Tag.order(:name)
    end

    # Finds the demo tag created by this plugin
    #
    # @return [Tag, nil]
    def demo_tag
      Tag.find_by(name: DEMO_TAG_NAME)
    end

    # Creates the demo tag if it doesn't exist
    #
    # @return [Tag]
    def ensure_demo_tag_exists!
      Tag.find_or_create_by!(name: DEMO_TAG_NAME)
    end

    # Checks if demo tag exists
    #
    # @return [Boolean]
    def demo_tag_exists?
      Tag.exists?(name: DEMO_TAG_NAME)
    end
  end
end

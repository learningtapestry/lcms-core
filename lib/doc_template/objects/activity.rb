# frozen_string_literal: true

module DocTemplate
  module Objects
    class Activity
      include ActiveModel::Model
      include ActiveModel::Attributes
      include DocTemplate::Objects::TocHelpers

      class Item
        include ActiveModel::Model
        include ActiveModel::Attributes
        include DocTemplate::Objects::AttributeAccess

        attribute :activity_type, :string
        attribute :activity_title, :string
        attribute :activity_source, :string
        attribute :activity_source_materials, :string
        attribute :activity_materials, :string
        attribute :activity_standard, :string
        attribute :activity_mathematical_practice, :string
        attribute :activity_time, :integer, default: 0
        attribute :activity_priority, :integer, default: 0
        attribute :activity_metacognition, :string
        attribute :activity_guidance, :string
        attribute :activity_content_development_notes, :string
        attribute :alert, :string
        attribute :optional, :boolean, default: false

        # toc attributes
        attribute :anchor, :string
        attribute :handled, :boolean, default: false
        attribute :idx, :integer
        attribute :level, :integer, default: 2

        attribute :material_ids, :json_array, default: -> { [] }

        def initialize(attrs = {})
          known = self.class.attribute_names.map(&:to_s)
          super(attrs.to_h.select { |k, _| known.include?(k.to_s) })
        end

        # Aliases mirroring prefixed fields — used by TocHelpers, MetadataHelpers, and tag classes
        def title    = activity_title
        def time     = activity_time
        def priority = activity_priority
      end

      # Backward compatibility alias
      Activity = Item

      attr_accessor :children

      attribute :idx, :integer
      attribute :task_counter, :json_hash, default: -> { {} }

      def initialize(attrs = {})
        attrs = attrs.to_h.stringify_keys
        children_data = attrs.delete("children") || []
        known = self.class.attribute_names.map(&:to_s)
        super(attrs.select { |k, _| known.include?(k) })
        @children = children_data.map { |c| c.is_a?(Item) ? c : Item.new(c) }
      end

      def self.build_from(data)
        copy = Marshal.load Marshal.dump(data)
        activity_data =
          copy.map do |d|
            d.transform_keys! { |k| k.to_s.underscore }
            d["activity_time"] = d["activity_time"].to_s[/\d+/].to_i
            d["optional"] = d["optional"]&.casecmp("optional")&.zero?
            d
          end
        new(set_index(children: activity_data))
      end
    end
  end
end

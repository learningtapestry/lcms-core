# frozen_string_literal: true

module DocTemplate
  module Objects
    class Sections
      include ActiveModel::Model
      include ActiveModel::Attributes
      include DocTemplate::Objects::TocHelpers

      class Section
        include ActiveModel::Model
        include ActiveModel::Attributes
        include DocTemplate::Objects::AttributeAccess

        attribute :summary, :string
        attribute :time, :integer, default: 0
        attribute :title, :string
        attribute :template_type, :string, default: "core"

        # toc attributes
        attribute :handled, :boolean, default: false
        attribute :idx, :integer
        attribute :level, :integer, default: 1
        attribute :anchor, :string

        attribute :material_ids, :json_array, default: -> { [] }

        attr_accessor :children

        def initialize(attrs = {})
          attrs = attrs.to_h.stringify_keys
          children_data = attrs.delete("children") || []
          known = self.class.attribute_names.map(&:to_s)
          super(attrs.select { |k, _| known.include?(k) })
          @children = children_data.map { |c| c.is_a?(DocTemplate::Objects::Activity::Item) ? c : DocTemplate::Objects::Activity::Item.new(c) }
        end

        def anchor
          super.presence || DocTemplate::Objects::MetadataHelpers.build_anchor_from(self)
        end

        def add_activity(activity)
          self.time += Integer(activity.time)
          activity.handled = true
          children << activity
        end
      end

      attr_accessor :children

      attribute :idx, :integer

      def initialize(attrs = {})
        attrs = attrs.to_h.stringify_keys
        children_data = attrs.delete("children") || []
        known = self.class.attribute_names.map(&:to_s)
        super(attrs.select { |k, _| known.include?(k) })
        @children = children_data.map { |c| c.is_a?(Section) ? c : Section.new(c) }
      end

      def self.build_from(data)
        copy = Marshal.load Marshal.dump(data)
        sections = copy.map do |metadata|
          metadata[:summary] = DocTemplate.sanitizer.strip_html_element(metadata[:summary])
          metadata.transform_keys { |k| k.to_s.gsub("section-", "").underscore }
        end
        new(set_index(children: sections))
      end

      def add_break
        idx = children.index { |c| !c.handled } || -1
        section =
          Section.new(title: "Foundational Skills Lesson", anchor: "optbreak", time: 0, children: [])
        children.insert(idx - 1, section)
      end
    end
  end
end

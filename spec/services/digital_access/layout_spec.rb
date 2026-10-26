# frozen_string_literal: true

require "rails_helper"

describe DigitalAccess::Layout do
  # In-memory Drive: `tree` maps a folder id to its child folder names; a
  # child's id is "<parent id>/<name>". #folder records what gets created.
  let(:fake_drive) do
    Class.new do
      attr_reader :created

      def initialize(tree)
        @tree = tree
        @created = []
      end

      def children(folder_id)
        Array(@tree[folder_id]).map { DigitalAccess::Drive::Item.new(id: "#{folder_id}/#{it}", name: it, folder: true) }
      end

      def folder(name, parent_id)
        @created << "#{parent_id}/#{name}"
        "#{parent_id}/#{name}"
      end
    end
  end
  let(:source_tree) do
    {
      "src" => ["Unit 1: Plants and Animals", "Unit 2: Weather"],
      "src/Unit 1: Plants and Animals" => ["Section 1 - Seeds", "Section 2 - Roots"],
      "src/Unit 1: Plants and Animals/Section 1 - Seeds" => ["Lesson 01 How seeds travel", "Lesson 2 Sprouts"]
    }
  end
  let(:drive) { fake_drive.new(source_tree) }
  let(:lesson1) { instance_double(DocumentPresenter, lesson_number: "1", lesson_title: "Seeds") }
  let(:lesson3) { instance_double(DocumentPresenter, lesson_number: "3", lesson_title: "Leaves") }
  let(:section1) { instance_double(SectionPresenter, section_number: "1", section_title: "Seeds", lessons: [lesson1, lesson3]) }
  let(:section3) { instance_double(SectionPresenter, section_number: "3", section_title: "Fruit", lessons: []) }
  let(:unit) do
    instance_double(UnitPresenter, course: "Kindergarten Science", unit_id: "k-u1", unit_title: "Plants",
                                   unit_number: "1", sections: [section1, section3])
  end

  subject(:course) { described_class.new(unit, drive:, output_root_id: "out", source_root_id: "src").build }

  it "names the folders after the matching Non-LCMS folders and links each to it" do
    unit_node = course.children.first
    section_node = unit_node.children.first

    expect(course).to have_attributes(name: "Kindergarten Science", folder_id: "out/Kindergarten Science", source_id: "src")
    expect(unit_node).to have_attributes(name: "Unit 1: Plants and Animals", record: unit,
                                         folder_id: "out/Kindergarten Science/Unit 1: Plants and Animals",
                                         source_id: "src/Unit 1: Plants and Animals")
    expect(section_node).to have_attributes(name: "Section 1 - Seeds", record: section1,
                                            source_id: "src/Unit 1: Plants and Animals/Section 1 - Seeds")
    expect(section_node.children.first).to have_attributes(name: "Lesson 01 How seeds travel", record: lesson1)
  end

  it "names the rest from the metadata, with no Non-LCMS folder" do
    unit_node = course.children.first

    expect(unit_node.children.first.children.last).to have_attributes(name: "Lesson 3: Leaves", source_id: nil)
    expect(unit_node.children.last).to have_attributes(name: "Section 3: Fruit", source_id: nil)
  end

  it "matches a unit folder by its unit id" do
    source_tree["src"] = ["K-U1 Plants"]

    expect(course.children.first).to have_attributes(name: "K-U1 Plants", source_id: "src/K-U1 Plants")
  end

  context "without a Non-LCMS Root Folder" do
    subject(:course) { described_class.new(unit, drive:, output_root_id: "out").build }

    it "names every folder from the metadata" do
      expect(course.children.first.name).to eq "Unit 1: Plants"
      expect(course.children.first.children.map(&:name)).to eq ["Section 1: Seeds", "Section 3: Fruit"]
      expect(course.source_id).to be_nil
    end
  end

  context "without an output root (the Full Unit Content zip)" do
    subject(:course) { described_class.new(unit, drive:, output_root_id: nil, source_root_id: "src").build }

    it "names the folders without creating any" do
      unit_node = course.children.first

      expect(unit_node).to have_attributes(name: "Unit 1: Plants and Animals", folder_id: nil)
      expect(unit_node.children.first.children.first).to have_attributes(name: "Lesson 01 How seeds travel", folder_id: nil)
      expect(drive.created).to be_empty
    end
  end

  describe ".numbered?" do
    it "reads the number after the level, ignoring separators, case and leading zeros" do
      expect(described_class.numbered?("Lesson 03 - Roots", "lesson", "3")).to be true
      expect(described_class.numbered?("LESSON 3a", "lesson", "3A")).to be true
      expect(described_class.numbered?("Lesson 13 Roots", "lesson", "3")).to be false
      expect(described_class.numbered?("Lessons learned", "lesson", "3")).to be false
      expect(described_class.numbered?("Lesson 3", "lesson", nil)).to be false
    end
  end
end

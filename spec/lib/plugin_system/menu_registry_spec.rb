# frozen_string_literal: true

require "rails_helper"

RSpec.describe PluginSystem::MenuRegistry do
  before do
    described_class.clear!
  end

  after do
    described_class.clear!
  end

  describe ".register" do
    it "registers a simple menu item" do
      described_class.register(:test_plugin, label: "Test", path: :root_path)

      expect(described_class.items).to include(
        hash_including(plugin: :test_plugin, label: "Test", path: :root_path)
      )
    end

    it "registers a menu item with icon" do
      described_class.register(:test_plugin, label: "Test", path: :root_path, icon: "bi-star")

      item = described_class.items.find { |i| i[:plugin] == :test_plugin }
      expect(item[:icon]).to eq("bi-star")
    end

    it "registers a dropdown menu" do
      described_class.register(
        :analytics,
        label: "Analytics",
        dropdown: [
          { label: "Dashboard", path: :root_path },
          { divider: true },
          { label: "Events", path: :root_path }
        ]
      )

      item = described_class.items.find { |i| i[:plugin] == :analytics }
      expect(item[:dropdown]).to be_an(Array)
      expect(item[:dropdown].size).to eq(3)
    end

    it "replaces existing registration for same plugin" do
      described_class.register(:test_plugin, label: "Old Label", path: :root_path)
      described_class.register(:test_plugin, label: "New Label", path: :root_path)

      items = described_class.items.select { |i| i[:plugin] == :test_plugin }
      expect(items.size).to eq(1)
      expect(items.first[:label]).to eq("New Label")
    end
  end

  describe ".items" do
    it "returns empty array when no items registered" do
      expect(described_class.items).to eq([])
    end

    it "sorts items by position" do
      described_class.register(:third, label: "Third", path: :root_path, position: 300)
      described_class.register(:first, label: "First", path: :root_path, position: 100)
      described_class.register(:second, label: "Second", path: :root_path, position: 200)

      labels = described_class.items.map { |i| i[:label] }
      expect(labels).to eq(%w(First Second Third))
    end

    it "places items without position at the end" do
      described_class.register(:positioned, label: "Positioned", path: :root_path, position: 100)
      described_class.register(:unpositioned, label: "Unpositioned", path: :root_path)

      labels = described_class.items.map { |i| i[:label] }
      expect(labels).to eq(%w(Positioned Unpositioned))
    end
  end

  describe ".any?" do
    it "returns false when no items registered" do
      expect(described_class.any?).to be false
    end

    it "returns true when items are registered" do
      described_class.register(:test, label: "Test", path: :root_path)
      expect(described_class.any?).to be true
    end
  end

  describe ".clear!" do
    it "removes all registered items" do
      described_class.register(:test1, label: "Test 1", path: :root_path)
      described_class.register(:test2, label: "Test 2", path: :root_path)

      described_class.clear!

      expect(described_class.items).to eq([])
    end

    it "removes all menu items added to built-in menus" do
      described_class.add_to(:resources, plugin: :test, label: "Test", path: :root_path)

      described_class.clear!

      expect(described_class.items_for(:resources)).to eq([])
    end
  end

  describe ".add_to" do
    it "adds an item to a built-in menu" do
      described_class.add_to(:resources, plugin: :my_plugin, label: "My Item", path: :root_path)

      items = described_class.items_for(:resources)
      expect(items).to include(
        hash_including(plugin: :my_plugin, label: "My Item", path: :root_path)
      )
    end

    it "adds item with icon and divider_before" do
      described_class.add_to(
        :resources,
        plugin: :my_plugin,
        label: "My Item",
        path: :root_path,
        icon: "bi-star",
        divider_before: true
      )

      item = described_class.items_for(:resources).first
      expect(item[:icon]).to eq("bi-star")
      expect(item[:divider_before]).to be true
    end

    it "replaces existing registration for same plugin in same menu" do
      described_class.add_to(:resources, plugin: :my_plugin, label: "Old", path: :root_path)
      described_class.add_to(:resources, plugin: :my_plugin, label: "New", path: :root_path)

      items = described_class.items_for(:resources)
      expect(items.size).to eq(1)
      expect(items.first[:label]).to eq("New")
    end

    it "allows same plugin to add items to different menus" do
      described_class.add_to(:resources, plugin: :my_plugin, label: "In Resources", path: :root_path)
      described_class.add_to(:users, plugin: :my_plugin, label: "In Users", path: :root_path)

      expect(described_class.items_for(:resources).first[:label]).to eq("In Resources")
      expect(described_class.items_for(:users).first[:label]).to eq("In Users")
    end
  end

  describe ".items_for" do
    it "returns empty array when no items for menu" do
      expect(described_class.items_for(:resources)).to eq([])
    end

    it "sorts items by position" do
      described_class.add_to(:resources, plugin: :third, label: "Third", path: :root_path, position: 300)
      described_class.add_to(:resources, plugin: :first, label: "First", path: :root_path, position: 100)
      described_class.add_to(:resources, plugin: :second, label: "Second", path: :root_path, position: 200)

      labels = described_class.items_for(:resources).map { |i| i[:label] }
      expect(labels).to eq(%w(First Second Third))
    end

    it "does not mix items from different menus" do
      described_class.add_to(:resources, plugin: :res_plugin, label: "Resources Item", path: :root_path)
      described_class.add_to(:users, plugin: :users_plugin, label: "Users Item", path: :root_path)

      expect(described_class.items_for(:resources).size).to eq(1)
      expect(described_class.items_for(:users).size).to eq(1)
    end
  end

  describe ".has_items_for?" do
    it "returns false when no items for menu" do
      expect(described_class.has_items_for?(:resources)).to be false
    end

    it "returns true when items exist for menu" do
      described_class.add_to(:resources, plugin: :test, label: "Test", path: :root_path)
      expect(described_class.has_items_for?(:resources)).to be true
    end
  end
end

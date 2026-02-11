# frozen_string_literal: true

require "rails_helper"

RSpec.describe PluginMenuHelper, type: :helper do
  before do
    PluginSystem::MenuRegistry.clear!
  end

  after do
    PluginSystem::MenuRegistry.clear!
  end

  describe "#render_plugin_menu_items" do
    context "when no items registered" do
      it "returns empty string" do
        expect(helper.render_plugin_menu_items).to eq("")
      end
    end

    context "when simple item registered" do
      before do
        PluginSystem::MenuRegistry.register(
          :test_plugin,
          label: "Test Plugin",
          path: :root_path
        )
      end

      it "renders nav-item with link" do
        result = helper.render_plugin_menu_items

        expect(result).to have_css("li.nav-item")
        expect(result).to have_css("a.nav-link", text: "Test Plugin")
      end
    end

    context "when item with icon registered" do
      before do
        PluginSystem::MenuRegistry.register(
          :test_plugin,
          label: "Test Plugin",
          path: :root_path,
          icon: "bi-star"
        )
      end

      it "renders icon before label" do
        result = helper.render_plugin_menu_items

        expect(result).to have_css("i.bi.bi-star")
        expect(result).to have_css("a.nav-link", text: /Test Plugin/)
      end
    end

    context "when dropdown menu registered" do
      before do
        PluginSystem::MenuRegistry.register(
          :analytics,
          label: "Analytics",
          dropdown: [
            { label: "Dashboard", path: :root_path },
            { divider: true },
            { label: "Events", path: :root_path }
          ]
        )
      end

      it "renders dropdown structure" do
        result = helper.render_plugin_menu_items

        expect(result).to have_css("li.nav-item.dropdown")
        expect(result).to have_css("a.nav-link.dropdown-toggle", text: "Analytics")
        expect(result).to have_css("ul.dropdown-menu")
      end

      it "renders dropdown items" do
        result = helper.render_plugin_menu_items

        expect(result).to have_css("a.dropdown-item", text: "Dashboard")
        expect(result).to have_css("a.dropdown-item", text: "Events")
      end

      it "renders dividers" do
        result = helper.render_plugin_menu_items

        expect(result).to have_css("hr.dropdown-divider")
      end
    end

    context "when multiple items registered" do
      before do
        PluginSystem::MenuRegistry.register(:second, label: "Second", path: :root_path, position: 200)
        PluginSystem::MenuRegistry.register(:first, label: "First", path: :root_path, position: 100)
      end

      it "renders items in position order" do
        result = helper.render_plugin_menu_items

        # First should appear before Second in the HTML
        first_pos = result.index("First")
        second_pos = result.index("Second")

        expect(first_pos).to be < second_pos
      end
    end
  end

  describe "#render_plugin_items_for" do
    context "when no items for menu" do
      it "returns empty string" do
        expect(helper.render_plugin_items_for(:resources)).to eq("")
      end
    end

    context "when items registered for menu" do
      before do
        PluginSystem::MenuRegistry.add_to(
          :resources,
          plugin: :my_plugin,
          label: "My Item",
          path: :root_path
        )
      end

      it "renders dropdown item" do
        result = helper.render_plugin_items_for(:resources)

        expect(result).to have_css("li")
        expect(result).to have_css("a.dropdown-item", text: "My Item")
      end
    end

    context "when item has icon" do
      before do
        PluginSystem::MenuRegistry.add_to(
          :resources,
          plugin: :my_plugin,
          label: "My Item",
          path: :root_path,
          icon: "bi-star"
        )
      end

      it "renders icon before label" do
        result = helper.render_plugin_items_for(:resources)

        expect(result).to have_css("i.bi.bi-star")
        expect(result).to have_css("a.dropdown-item", text: /My Item/)
      end
    end

    context "when item has divider_before" do
      before do
        PluginSystem::MenuRegistry.add_to(
          :resources,
          plugin: :my_plugin,
          label: "My Item",
          path: :root_path,
          divider_before: true
        )
      end

      it "renders divider before the item" do
        result = helper.render_plugin_items_for(:resources)

        expect(result).to have_css("hr.dropdown-divider")
        expect(result).to have_css("a.dropdown-item", text: "My Item")

        # Divider should come before the item
        divider_pos = result.index("dropdown-divider")
        item_pos = result.index("My Item")
        expect(divider_pos).to be < item_pos
      end
    end

    context "when multiple items registered" do
      before do
        PluginSystem::MenuRegistry.add_to(:resources, plugin: :second, label: "Second", path: :root_path, position: 200)
        PluginSystem::MenuRegistry.add_to(:resources, plugin: :first, label: "First", path: :root_path, position: 100)
      end

      it "renders items in position order" do
        result = helper.render_plugin_items_for(:resources)

        first_pos = result.index("First")
        second_pos = result.index("Second")

        expect(first_pos).to be < second_pos
      end
    end

    context "when items registered for different menu" do
      before do
        PluginSystem::MenuRegistry.add_to(:users, plugin: :user_plugin, label: "User Item", path: :root_path)
      end

      it "does not render items from other menus" do
        result = helper.render_plugin_items_for(:resources)

        expect(result).to eq("")
      end
    end
  end

  describe "#resolve_plugin_path" do
    it "resolves symbol route helpers" do
      path = helper.send(:resolve_plugin_path, :root_path)
      expect(path).to eq("/")
    end

    it "returns string paths as-is" do
      path = helper.send(:resolve_plugin_path, "/custom/path")
      expect(path).to eq("/custom/path")
    end

    it "evaluates proc paths" do
      path = helper.send(:resolve_plugin_path, -> { "/dynamic/path" })
      expect(path).to eq("/dynamic/path")
    end
  end
end

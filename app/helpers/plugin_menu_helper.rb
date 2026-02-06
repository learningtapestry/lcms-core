# frozen_string_literal: true

# Helper for rendering plugin menu items in navigation
#
# Provides methods to render menu items registered by plugins via PluginSystem::MenuRegistry.
# Supports standalone items, dropdown menus, and injection into existing menus.
module PluginMenuHelper
  # Renders all registered standalone plugin menu items
  #
  # @return [ActiveSupport::SafeBuffer] HTML for plugin menu items
  def render_plugin_menu_items
    return "".html_safe unless defined?(PluginSystem::MenuRegistry) && PluginSystem::MenuRegistry.any?

    safe_join(PluginSystem::MenuRegistry.items.map { |item| render_plugin_menu_item(item) })
  end

  # Renders plugin items registered for a specific built-in menu
  #
  # @param menu_id [Symbol] identifier of the built-in menu (:resources, :users)
  # @return [ActiveSupport::SafeBuffer] HTML for plugin dropdown items
  def render_plugin_items_for(menu_id)
    return "".html_safe unless defined?(PluginSystem::MenuRegistry)
    return "".html_safe unless PluginSystem::MenuRegistry.has_items_for?(menu_id)

    items = PluginSystem::MenuRegistry.items_for(menu_id)
    safe_join(items.map { |item| render_injected_dropdown_item(item) })
  end

  private

  # Renders an item injected into a built-in dropdown menu
  #
  # @param item [Hash] menu item definition
  # @return [ActiveSupport::SafeBuffer] HTML for the dropdown item
  def render_injected_dropdown_item(item)
    parts = []

    # Add divider before if requested
    if item[:divider_before]
      parts << content_tag(:li) { content_tag(:hr, nil, class: "dropdown-divider") }
    end

    path = resolve_plugin_path(item[:path])
    label = item[:icon].present? ? "#{icon_tag(item[:icon])} #{item[:label]}".html_safe : item[:label]

    parts << content_tag(:li) { link_to(label, path, class: "dropdown-item") }

    safe_join(parts)
  end

  # Renders a single plugin menu item (simple or dropdown)
  #
  # @param item [Hash] menu item definition
  # @return [ActiveSupport::SafeBuffer] HTML for the menu item
  def render_plugin_menu_item(item)
    if item[:dropdown].present?
      render_plugin_dropdown(item)
    else
      render_plugin_simple_item(item)
    end
  end

  # Renders a simple navigation item
  #
  # @param item [Hash] menu item definition
  # @return [ActiveSupport::SafeBuffer] HTML for simple nav item
  def render_plugin_simple_item(item)
    path = resolve_plugin_path(item[:path])
    label = build_plugin_label(item)

    content_tag(:li, class: "nav-item") do
      link_to(label, path, class: "nav-link")
    end
  end

  # Renders a dropdown menu
  #
  # @param item [Hash] menu item definition with :dropdown array
  # @return [ActiveSupport::SafeBuffer] HTML for dropdown menu
  def render_plugin_dropdown(item)
    dropdown_id = "dropdown#{item[:plugin].to_s.camelize}"
    label = build_plugin_label(item)

    content_tag(:li, class: "nav-item dropdown") do
      toggle = link_to(
        "#",
        class: "nav-link dropdown-toggle",
        id: dropdown_id,
        role: "button",
        data: { bs_toggle: "dropdown" },
        aria: { expanded: false }
      ) { label }

      menu = content_tag(:ul, class: "dropdown-menu", aria: { labelledby: dropdown_id }) do
        safe_join(item[:dropdown].map { |subitem| render_plugin_dropdown_item(subitem) })
      end

      toggle + menu
    end
  end

  # Renders a single dropdown menu item
  #
  # @param subitem [Hash] dropdown item definition
  # @return [ActiveSupport::SafeBuffer] HTML for dropdown item
  def render_plugin_dropdown_item(subitem)
    if subitem[:divider]
      content_tag(:li) { content_tag(:hr, nil, class: "dropdown-divider") }
    else
      path = resolve_plugin_path(subitem[:path])
      label = subitem[:icon].present? ? "#{icon_tag(subitem[:icon])} #{subitem[:label]}".html_safe : subitem[:label]

      content_tag(:li) do
        link_to(label, path, class: "dropdown-item")
      end
    end
  end

  # Resolves a path from symbol (route helper) or returns string path as-is
  #
  # @param path [Symbol, String] route helper name or path string
  # @return [String] resolved path
  def resolve_plugin_path(path)
    case path
    when Symbol
      send(path)
    when Proc
      instance_exec(&path)
    else
      path.to_s
    end
  end

  # Builds label with optional icon
  #
  # @param item [Hash] menu item definition
  # @return [ActiveSupport::SafeBuffer, String] label with optional icon
  def build_plugin_label(item)
    if item[:icon].present?
      "#{icon_tag(item[:icon])} #{item[:label]}".html_safe
    else
      item[:label]
    end
  end

  # Generates Bootstrap icon tag
  #
  # @param icon_class [String] Bootstrap icon class (e.g., "bi-graph-up")
  # @return [ActiveSupport::SafeBuffer] HTML for icon
  def icon_tag(icon_class)
    content_tag(:i, nil, class: "bi #{icon_class}")
  end
end

# frozen_string_literal: true

require "rails_helper"

describe "config/plugin_paths.rb" do
  let(:config) { Rails.application.config }
  let(:plugin_dirs) { Rails.root.join("lib/plugins").children.select(&:directory?) }
  let(:code_dirs) do
    plugin_dirs.flat_map do |plugin_path|
      app_dirs = plugin_path.join("app").exist? ? plugin_path.join("app").children.select(&:directory?) : []
      app_dirs.reject { |dir| %w(assets javascript views).include?(dir.basename.to_s) } +
        [plugin_path.join("lib")].select(&:exist?)
    end
  end

  it "autoloads every plugin app/ subdirectory and lib/" do
    expect(code_dirs).not_to be_empty
    expect(config.autoload_paths.map(&:to_s)).to include(*code_dirs.map(&:to_s))
  end

  it "eager loads the same directories, so production boots them up front" do
    expect(config.eager_load_paths.map(&:to_s)).to include(*code_dirs.map(&:to_s))
  end

  it "puts plugin views before core views, so a plugin can override a core template" do
    view_paths = ApplicationController.view_paths.map(&:to_path)
    plugin_views = plugin_dirs.map { |p| p.join("app/views").to_s }.select { |p| File.directory?(p) }
    core_index = view_paths.index(Rails.root.join("app/views").to_s)

    expect(plugin_views).not_to be_empty
    plugin_views.each { |path| expect(view_paths.index(path)).to be < core_index }
  end

  it "does not treat plugin views as code" do
    views = plugin_dirs.map { |p| p.join("app/views") }.select(&:exist?).map(&:to_s)

    expect(views).not_to be_empty
    expect(config.autoload_paths.map(&:to_s)).not_to include(*views)
  end
end

# frozen_string_literal: true

# Plugin Demo Routes
#
# Access at: /plugin-demo/tags


namespace :admin do
  namespace :plugin_demo, path: "plugin-demo" do
    resources :tags, only: [:index] do
      post :create_demo, on: :collection
    end
  end
end

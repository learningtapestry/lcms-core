# frozen_string_literal: true

class Setting
  # Virtual model for the :admin_view_links setting. Each key holds a list of
  # URL patterns (one per line in the form), edited but not added/removed.
  class AdminViewLinks < Base
    RULES = {
      %i(documents) => { type: :list },
      %i(materials) => { type: :list },
      %i(sections) => { type: :list },
      %i(units) => { type: :list }
    }.freeze
  end
end

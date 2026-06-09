# frozen_string_literal: true

class Setting
  # Virtual model for the :pdf setting: per-content-type PDF page geometry
  # (`default`, `handout`, and any fork block). The SAME geometry schema applies
  # to every content-type block, so RULES are expressed relative to a block and
  # `rule_for` strips the leading content-type segment before matching. Casting,
  # validation, overlay and form descriptors all come from Setting::Base.
  #
  # Renderer selection is a separate setting (:pdf_renderer), not part of this
  # geometry model — see SETTINGS in config/initializers/lcms_constants.rb.
  class Pdf < Base
    RULES = {
      %i(dpi) => { type: :integer, min: 1 },
      %i(image_dpi) => { type: :integer, min: 1 },
      %i(header) => { type: :boolean },
      %i(name_date) => { type: :boolean },
      %i(orientation) => { type: :string, in: %w(portrait landscape) },
      %i(margin top) => { type: :length },
      %i(margin right) => { type: :length },
      %i(margin bottom) => { type: :length },
      %i(margin left) => { type: :length },
      %i(padding right) => { type: :integer, min: 0 },
      %i(padding left) => { type: :integer, min: 0 }
    }.freeze

    private

    # Rules apply within a content-type block, so drop the leading content-type
    # segment (e.g. %w(default margin top) -> %i(margin top)) before matching.
    # This is the one thing that differs from Base's absolute-path rules.
    def rule_for(path)
      self.class::RULES[path[1..].map(&:to_sym)]
    end
  end
end

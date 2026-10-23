# frozen_string_literal: true

module DocTemplate
  module Tags
    RE_BOLD = /(\[b\]([^\[]*)\[b:end\])/i
    RE_ITALIC = /(\[i\]([^\[]*)\[i:end\])/i
    RE_LINE_BREAK = /\[line-break\]/i
    TAG_LINE_BREAK = "<br/><br/>"

    # Code-level tag hooks for plugins, set in a plugin's `setup!`. Empty in
    # core. Per tag (keyed by TAG_NAME): "stop_tags" / "stop_materials_tags"
    # (override the tag class's STOP_TAGS / STOP_MATERIALS_TAGS), "templates"
    # (template file per context) and "extend-params-with" ("Module.method").
    # Top level: "templates_paths" (directories searched before core's).
    # Wording and styling that appear in output live in Settings[:documents].
    mattr_accessor :config, default: {}

    #
    # Substitutes the following custom tags with plain HTML markup:
    #
    #  # [b]Text[b:end] -> <b>Text</b>
    #  # [i]Text[i:end] -> <i>Text</i>
    #  # [line-break] -> <br/><br/>
    #
    # @param [String] content Content to substitute vars in
    # @return [String]
    def self.substitute_tags_in(content)
      return "" if content.blank?

      # do gsub and mark if any matches
      parsed_content = content.to_s
                         .gsub(RE_LINE_BREAK, TAG_LINE_BREAK)
                         .gsub(RE_ITALIC, '<i>\2</i>')
                         .gsub(RE_BOLD, '<b>\2</b>')
      # if there are any matches, call recursively
      parsed_content == content ? parsed_content.gsub("\n", "<br/>") : substitute_tags_in(parsed_content)
    end
  end
end

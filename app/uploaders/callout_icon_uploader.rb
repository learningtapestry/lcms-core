# frozen_string_literal: true

require "carrierwave/processing/mini_magick"

# Icons for the client-configurable callout types (admin Settings > Documents >
# Callout Types, rendered by DocTemplate::Tags::CalloutTag).
#
# A subclass rather than a `process` on ImageUploader itself, because that class
# is shared with the brandmark/logo (SettingsForm::FlatGroup#process_image_uploads)
# and the generic Admin::SettingsController#upload_image endpoint, which have
# their own size needs. Only callout icons are normalized here.
class CalloutIconUploader < ImageUploader
  include CarrierWave::MiniMagick

  # Longest edge kept for the stored icon.
  #
  # The icon renders at 24pt (.o-ld-callout__icon-img in pdf.scss / gdoc.scss),
  # which is the convergent value for a margin-column callout icon in print:
  # Asciidoctor PDF's admonition theme defaults to 24pt and LaTeX's awesomebox
  # uses \Huge (24.88pt), both against a ~10.5pt body. It is also the standard
  # "standalone icon" step in Material and Carbon. So the display size is not
  # the thing to change here — only the stored source.
  #
  # At the 300dpi the PDF printers are configured with (Settings::DEFAULTS
  # [:pdf][:default][:image_dpi]), 24pt needs just 24/72 * 300 = 100px. 256px
  # is ~2.5x that, and still covers a future bump to a 48pt display size (which
  # would need 200px) without a re-upload.
  #
  # Deliberately below the ~512px a general-purpose icon guideline would
  # suggest, because of a constraint specific to this pipeline: the Gdoc export
  # inlines the icon as a base64 data URI once per callout OCCURRENCE in the
  # document (CalloutTag#callout_icon_url). A lesson with 20 callouts carries 20
  # copies, so source pixels beyond what 300dpi actually needs are paid for 20
  # times over in the Drive import payload.
  MAX_EDGE = 256

  # resize_to_limit, not resize_to_fit: it only ever shrinks, so a small icon
  # that is already the right size is passed through untouched rather than
  # upscaled into a blurry one. Aspect ratio is preserved either way, so a
  # non-square icon stays non-square.
  process resize_to_limit: [MAX_EDGE, MAX_EDGE]
end

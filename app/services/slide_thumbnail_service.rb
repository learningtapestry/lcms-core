# frozen_string_literal: true

require "google/apis/slides_v1"
require "lt/google/api/auth/cli"

#
# The thumbnail of one slide of a Google Slides deck, for `[slide: id, n, size]`
# tags. The image comes from the Slides API (pages.getThumbnail) and is stored
# in the app's bucket, because the API's own image URL expires after about 30
# minutes. Stored thumbnails are keyed by the deck's revision, so a document
# re-import only asks the API again once the deck has been edited.
#
# Needs the Google Slides API enabled for the app's Google Cloud project; the
# Drive credentials used for imports already carry a scope the API accepts.
#
class SlideThumbnailService
  class Error < StandardError; end

  Result = Struct.new(:image_url, :slide_url, keyword_init: true)

  PRESENTATION_ID_RE = %r{/presentation/d/([\w-]+)}

  # @param deck_url [String] the deck's Google Slides link
  # @param slide_number [Integer] 1-based
  # @return [Result]
  # @raise [Error] when the thumbnail cannot be produced
  def self.call(deck_url, slide_number)
    new(deck_url, slide_number).call
  end

  # Failures of the thumbnail download itself; reported as an Error so the
  # tag shows its placeholder instead of failing the document.
  NETWORK_ERRORS = [SocketError, Timeout::Error, SystemCallError, IOError, OpenSSL::SSL::SSLError].freeze

  def initialize(deck_url, slide_number)
    @deck_url = deck_url.to_s
    @slide_number = slide_number.to_i
  end

  def call
    raise Error, "#{@deck_url} is not a Google Slides link" unless presentation_id

    presentation = slides.get_presentation(presentation_id, fields: "revisionId,slides.objectId")
    page = Array(presentation.slides)[@slide_number - 1] if @slide_number.positive?
    raise Error, "the deck has no slide #{@slide_number}" unless page

    thumbnail = find_or_create(presentation.revision_id, page.object_id_prop)
    Result.new(image_url: thumbnail.file_url, slide_url: slide_url(page.object_id_prop))
  rescue Google::Apis::Error, Signet::AuthorizationError => e
    raise Error, "Google Slides: #{e.message}"
  rescue *NETWORK_ERRORS => e
    raise Error, "thumbnail download failed (#{e.class}: #{e.message})"
  end

  private

  def presentation_id
    @presentation_id ||= @deck_url[PRESENTATION_ID_RE, 1]
  end

  def find_or_create(revision_id, page_object_id)
    key = { presentation_id:, slide_number: @slide_number, revision_id: revision_id.to_s }
    SlideThumbnail.find_by(key) || SlideThumbnail.create!(**key, page_object_id:, file_url: store(page_object_id))
  rescue ActiveRecord::RecordNotUnique
    # Another document parse stored the same slide first: use its thumbnail.
    SlideThumbnail.find_by!(key)
  end

  # Downloads the API's (short-lived) PNG and stores it in the bucket.
  def store(page_object_id)
    thumbnail = slides.get_presentation_page_thumbnail(
      presentation_id, page_object_id,
      thumbnail_properties_mime_type: "PNG", thumbnail_properties_thumbnail_size: "LARGE"
    )
    response = Net::HTTP.get_response(URI(thumbnail.content_url))
    raise Error, "thumbnail download failed (HTTP #{response.code})" unless response.is_a?(Net::HTTPSuccess)

    Tempfile.create(%w(slide .png), binmode: true) do |file|
      file.write(response.body)
      file.rewind
      uploader = SlideThumbnailUploader.new
      uploader.store!(ActionDispatch::Http::UploadedFile.new(tempfile: file, filename: "slide.png", type: "image/png"))
      uploader.url
    end
  end

  def slide_url(page_object_id)
    "https://docs.google.com/presentation/d/#{presentation_id}/edit#slide=id.#{page_object_id}"
  end

  def slides
    @slides ||= Google::Apis::SlidesV1::SlidesService.new.tap do |service|
      service.authorization = Lt::Google::Api::Auth::Cli.new.credentials
    end
  end
end

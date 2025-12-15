# frozen_string_literal: true

require "lt/lcms/lesson/downloader/gdoc"

class MaterialBuildService
  EVENT_BUILT = "material:built"

  attr_reader :errors

  def initialize(credentials, opts = {})
    @credentials = credentials
    @errors = []
    @options = opts
  end

  def build(url)
    @url = url
    result = build_from_gdoc
    ActiveSupport::Notifications.instrument EVENT_BUILT, id: result.id
    result
  end

  private

  attr_reader :credentials, :material, :downloader, :options, :url

  def build_from_gdoc
    @downloader = ::Lt::Lcms::Lesson::Downloader::Gdoc.new(@credentials, url, options)
    create_material
    content = @downloader.download.content
    template = DocTemplate::Template.parse(content, type: :material)
    @errors = template.metadata_service.errors + template.documents.values.flat_map(&:errors)

    metadata = template.metadata_service.options_for(:default)[:metadata]
    material.update!(
      material_params.merge(
        css_styles: template.css_styles,
        identifier: metadata["identifier"].downcase,
        metadata: metadata.as_json,
        original_content: content
      )
    )

    material.document_parts.delete_all
    material.create_parts_for(template)
    material
  end

  def create_material
    @material = Material.find_or_initialize_by(file_id: downloader.file_id)
  end

  def material_params
    {
      last_modified_at: downloader.file.modified_time,
      last_author_email: downloader.file.last_modifying_user.try(:email_address),
      last_author_name: downloader.file.last_modifying_user.try(:display_name),
      name: downloader.file.name,
      reimported_at: Time.current,
      version: downloader.file.version
    }
  end
end

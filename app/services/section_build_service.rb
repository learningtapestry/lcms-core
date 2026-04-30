# frozen_string_literal: true

require "lt/lcms/lesson/downloader/gdoc"

class SectionBuildService
  EVENT_BUILT = "section:built"

  attr_reader :errors

  def initialize(credentials, opts = {})
    @credentials = credentials
    @errors = []
    @options = opts
  end

  def build_for(url)
    @content = download(url)
    @metadata = parse_metadata(content)
    @resource = SectionResourceUpsertService.call(metadata: metadata.as_json, source_link_data:)
    ActiveSupport::Notifications.instrument(EVENT_BUILT, id: resource.id)
    resource
  end

  private

  attr_reader :content, :credentials, :downloader, :metadata, :options, :resource

  def download(url)
    @downloader = ::Lt::Lcms::Lesson::Downloader::Gdoc.new(credentials, url, options).download
    @downloader.content
  end

  def parse_metadata(content)
    fragment = sanitized_fragment(content)
    table = DocTemplate::Tables::SectionMetadata.parse(fragment)
    @errors = table.errors.dup
    raise "No section metadata present" if !table.table_exist? || table.data.empty?
    raise "Invalid section metadata: #{@errors.join(', ')}" if @errors.any?

    DocTemplate::Objects::SectionMetadata.build_from(table.data)
  end

  def sanitized_fragment(content)
    doc = Nokogiri::HTML(content)
    body = DocTemplate.config["sanitizer"].constantize.sanitize(doc.xpath("//html/body/*").to_s)
    Nokogiri::HTML.fragment(body)
  end

  def source_link_data
    {
      "source" => {
        "gdoc" => {
          "file_id" => downloader.file_id,
          "name" => downloader.file.name,
          "timestamp" => Time.current.to_i,
          "url" => ::Lt::Lcms::Lesson::Downloader::Gdoc.gdoc_file_url(downloader.file_id)
        }
      }
    }
  end
end

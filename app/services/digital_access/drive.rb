# frozen_string_literal: true

module DigitalAccess
  #
  # The Google Drive calls the Teacher Bundle for Digital Access needs:
  # reading the client's Non-LCMS folders, creating the bundle's folders and
  # keeping copies of the client's files in step with their originals. The
  # Full Unit Content for Download reads the same folders and downloads the
  # files into its zip.
  #
  class Drive
    FOLDER_MIME = ::Lt::Google::Api::Drive::MIME_FOLDER
    # Marks a file copied from the Non-LCMS folders, so a later run can tell
    # its own copies from the LCMS documents beside them and refresh or remove
    # them when the original changes or goes away.
    SOURCE_ID = "lcmsSourceId"
    SOURCE_MODIFIED = "lcmsSourceModified"

    # Google Docs, Sheets, Slides and Drawings have no file to download: they
    # are exported, the first three to their Office format.
    EXPORTS = {
      "application/vnd.google-apps.document" =>
        ["application/vnd.openxmlformats-officedocument.wordprocessingml.document", ".docx"],
      "application/vnd.google-apps.spreadsheet" =>
        ["application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", ".xlsx"],
      "application/vnd.google-apps.presentation" =>
        ["application/vnd.openxmlformats-officedocument.presentationml.presentation", ".pptx"],
      "application/vnd.google-apps.drawing" => ["application/pdf", ".pdf"]
    }.freeze
    GOOGLE_APPS_MIME_PREFIX = "application/vnd.google-apps."

    Item = Struct.new(:id, :name, :folder, :mime_type, :modified_time, :app_properties, keyword_init: true)

    # @param service [Google::Apis::DriveV3::DriveService]
    def initialize(service)
      @service = service
    end

    # Folder id from a Google Drive folder link (or a bare id).
    def self.folder_id_for(url)
      url.to_s[%r{/folders/([\w-]+)}, 1] || url.to_s[/[?&]id=([\w-]+)/, 1] || url.to_s[/\A[\w-]{10,}\z/]
    end

    # Files and folders directly inside a folder.
    # @return [Array<Item>]
    def children(folder_id)
      items = []
      page_token = nil
      loop do
        response = @service.list_files(
          q: %("#{folder_id}" in parents and trashed = false),
          fields: "nextPageToken, files(id, name, mimeType, modifiedTime, appProperties)",
          page_token:, include_items_from_all_drives: true, supports_all_drives: true
        )
        Array(response&.files).each do |file|
          items << Item.new(id: file.id, name: file.name, folder: file.mime_type == FOLDER_MIME, mime_type: file.mime_type,
                            modified_time: file.modified_time&.to_s, app_properties: file.app_properties || {})
        end
        page_token = response&.next_page_token
        break if page_token.blank?
      end
      items
    end

    # A file's content and the name to save it under: the file itself, or a
    # Google Doc/Sheet/Slides exported to Word/Excel/PowerPoint ("Notes" ->
    # "Notes.docx"). Nil for what cannot be downloaded (Forms, shortcuts, ...).
    # @param item [Item]
    # @return [Array(String, String), nil] [filename, binary content]
    def download(item)
      io = StringIO.new("".b)
      export_mime, extension = EXPORTS[item.mime_type]
      if export_mime
        @service.export_file(item.id, export_mime, download_dest: io)
      elsif item.mime_type.to_s.start_with?(GOOGLE_APPS_MIME_PREFIX)
        return
      else
        @service.get_file(item.id, download_dest: io, supports_all_drives: true)
      end
      name = extension && !item.name.downcase.end_with?(extension) ? "#{item.name}#{extension}" : item.name
      [name, io.string]
    end

    # The folder named `name` inside `parent_id`, created when missing.
    def folder(name, parent_id)
      existing = children(parent_id).find { it.folder && it.name == name }
      return existing.id if existing

      file = ::Google::Apis::DriveV3::File.new(name:, mime_type: FOLDER_MIME, parents: [parent_id])
      @service.create_file(file, fields: "id", supports_all_drives: true).id
    end

    # Makes the copies in `target_id` match the files (not folders) in
    # `source_id`: new files are copied, changed ones re-copied, and copies
    # whose original is gone are removed. Anything else in the target (the
    # LCMS documents, sub-folders) is left alone. A nil source removes every
    # copy.
    def sync_copies(source_id, target_id)
      sources = source_id ? children(source_id).reject(&:folder).index_by(&:id) : {}
      kept = children(target_id).select { it.app_properties[SOURCE_ID].present? }.filter_map do |copy|
        source = sources[copy.app_properties[SOURCE_ID]]
        next source.id if source && source.modified_time == copy.app_properties[SOURCE_MODIFIED]

        @service.delete_file(copy.id, supports_all_drives: true)
        nil
      end

      sources.each_value do |source|
        next if kept.include?(source.id)

        file = ::Google::Apis::DriveV3::File.new(
          name: source.name, parents: [target_id],
          app_properties: { SOURCE_ID => source.id, SOURCE_MODIFIED => source.modified_time }
        )
        @service.copy_file(source.id, file, supports_all_drives: true)
      end
    end
  end
end

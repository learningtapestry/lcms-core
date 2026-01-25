# frozen_string_literal: true

module Google
  #
  # Service for interacting with Google Drive API.
  #
  # Provides methods for creating folders, finding files, and managing
  # the folder structure for document exports.
  #
  # @example Creating a folder
  #   service = Google::DriveService.new(document, {})
  #   folder_id = service.create_folder("my_folder")
  #
  # @example Finding an existing file
  #   service = Google::DriveService.new(document, {})
  #   file_id = service.file_id
  #
  # @see Lt::Google::Api::Drive
  #
  class DriveService < ::Lt::Google::Api::Drive
    include GoogleCredentials

    FOLDER_ID = ENV.fetch("GOOGLE_APPLICATION_FOLDER_ID", "PLEASE SET UP FOLDER ID")

    attr_reader :service

    # Factory method to create a new DriveService instance.
    #
    # @param document [DocumentPresenter, MaterialPresenter] the document/material to work with
    # @param options [Hash] configuration options
    # @return [DriveService] new instance
    def self.build(document, options = {})
      new document, options
    end

    # Escapes double quotes in file names for Google Drive API queries.
    #
    # @param file_name [String] the file name to escape
    # @return [String] escaped file name
    def self.escape_double_quotes(file_name)
      file_name.to_s.gsub('"', '\"')
    end

    # Copies files to a folder in Google Drive.
    #
    # @param file_ids [Array<String>] IDs of files to copy
    # @param folder_id [String] destination folder ID (defaults to parent)
    # @return [String] the folder ID containing copied files
    def copy(file_ids, folder_id = parent)
      super
    end

    # Creates a folder in Google Drive if it doesn't exist.
    #
    # @param folder_name [String] name of the folder to create
    # @param parent_id [String] parent folder ID (defaults to FOLDER_ID)
    # @return [String] the created or existing folder ID
    def create_folder(folder_name, parent_id = FOLDER_ID)
      super
    end

    # Initializes a new DriveService instance.
    #
    # @param document [DocumentPresenter, MaterialPresenter] the document/material to work with
    # @param options [Hash] configuration options
    # @option options [String] :folder_id override default folder ID
    # @option options [Array<String>] :subfolders additional subfolders to create
    # @option options [String] :gdoc_folder override default gdoc folder name
    def initialize(document, options)
      super(google_credentials)
      @document = document
      @options = options
    end

    # Finds an existing file by name in the parent folder.
    #
    # @return [String, nil] the file ID if found, nil otherwise
    def file_id
      @file_id ||=
        begin
          folder = @options[:folder_id] || parent
          file_name = document.base_filename
          # Escape double quotes
          escaped_name = self.class.escape_double_quotes(file_name)

          response = service.list_files(
            q: %("#{folder}" in parents and name = "#{escaped_name}" and mimeType = "#{MIME_FILE}" \
                and trashed = false),
            fields: "files(id)"
          )
          files = Array.wrap(response&.files)
          Rails.logger.warn "Multiple files: more than 1 file with same name: #{file_name}" \
            if files.size.positive?
          files.first&.id
        end
    end

    # Returns the parent folder ID, creating nested subfolders as needed.
    #
    # @return [String] the parent folder ID for the document
    def parent
      @parent ||=
        begin
          subfolders = (options[:subfolders] || []).unshift(options[:gdoc_folder] || document.gdoc_folder)
          parent_folder = FOLDER_ID
          subfolders.each do |folder|
            parent_folder = subfolder(folder, parent_folder)
          end
          parent_folder
        end
    end

    private

    attr_reader :document, :options

    # Queries for a folder by name within a parent folder.
    #
    # @param folder_name [String] name of the folder to find
    # @param parent_id [String] parent folder ID
    # @return [Google::Apis::DriveV3::FileList] list of matching folders
    def folder_query(folder_name, parent_id)
      query = %("#{parent_id}" in parents and name = "#{folder_name}" and mimeType =
                  "#{::Lt::Google::Api::Drive::MIME_FOLDER}" and trashed = false)
      service.list_files(q: query, fields: "files(id)")
    end

    # Gets or creates a subfolder within a parent folder.
    #
    # @param folder_name [String] name of the subfolder
    # @param parent_id [String] parent folder ID
    # @return [String] the subfolder ID
    def subfolder(folder_name, parent_id = FOLDER_ID)
      response = folder_query folder_name, parent_id
      files = response.files
      return create_folder(folder_name, parent_id) if files.empty?

      Rails.logger.warn "Multiple folders: more than 1 folder with same name: #{folder_name}" if files.size > 1
      response.files[0].id
    end
  end
end

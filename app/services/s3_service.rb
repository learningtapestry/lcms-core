# frozen_string_literal: true

require "aws-sdk-s3"

class S3Service
  def self.create_object(key)
    ::Aws::S3::Resource
      .new(region: ENV.fetch("AWS_REGION"))
      .bucket(ENV.fetch("AWS_S3_BUCKET_NAME"))
      .object(key)
  end

  # Reads data from an S3 object specified by the given URI.
  #
  # @param uri [URI] The URI of the S3 object. The URI should include the bucket name in the host
  #   and the object key in the path.
  # @return [String] The content of the S3 object as a string.
  #
  # @raise [RuntimeError] If the S3 object is not found or if there is a service error.
  # @raise [Aws::S3::Errors::NoSuchKey] If the specified key does not exist in the bucket.
  # @raise [Aws::S3::Errors::ServiceError] If there is an error with the S3 service.
  # @raise [StandardError] For any other unexpected errors.
  #
  def self.read_data_from_s3(uri)
    # Extract bucket and key from the URL
    bucket = uri.host.split(".").first
    key = URI.decode_www_form_component(uri.path[1..]) # Decode URL-encoded characters

    # Initialize the S3 client
    s3_client = Aws::S3::Client.new(
      region: ENV.fetch("AWS_REGION", "us-east-1"),
      access_key_id: ENV.fetch("AWS_ACCESS_KEY_ID", nil),
      secret_access_key: ENV.fetch("AWS_SECRET_ACCESS_KEY", nil)
    )

    # Fetch the object from S3
    response = s3_client.get_object(bucket:, key:)
    response.body.read
  rescue Aws::S3::Errors::NoSuchKey => e
    Rails.logger.error "S3 Error: Object not found - #{e.message}"
    raise "S3 object not found: #{key}"
  rescue Aws::S3::Errors::ServiceError => e
    Rails.logger.error "S3 Service Error: #{e.message}"
    raise "S3 service error: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Unexpected error while fetching S3 object: #{e.message}"
    raise "Unexpected error: #{e.message}"
  end

  # Uploads data to AWS S3 or local filesystem depending on configuration.
  #
  # This method handles file uploads by either storing them in S3 or saving them locally
  # if AWS_S3_BLOCK is enabled. Automatically sets cache control headers for S3 uploads.
  #
  # @param key [String] The S3 object key (path within the bucket). Example: "documents/123/file.pdf"
  # @param data [IO, StringIO, File, String] The data to be uploaded. Can be a file handle,
  #   string IO object, or raw string data.
  # @param options [Hash] Additional options to pass to Aws::S3::Object#put method.
  #   These options will be merged with default cache_control settings.
  #
  # @option options [String] :content_type The MIME type of the content (e.g., "application/pdf")
  # @option options [String] :acl The access control list (e.g., "public-read", "private")
  # @option options [Hash] :metadata Custom metadata to store with the object
  #
  # @return [String] The public URL of the uploaded object. For S3, returns the public URL.
  #   For local uploads (when AWS_S3_BLOCK is true), returns the local file path.
  #
  # @raise [Aws::S3::Errors::ServiceError] If there is an error communicating with S3
  # @raise [Errno::ENOENT] If the local directory cannot be created (local mode only)
  #
  # @example Upload a PDF file
  #   file = File.open("document.pdf", "rb")
  #   url = S3Service.upload("documents/123/doc.pdf", file, content_type: "application/pdf")
  #   # => "https://s3.amazonaws.com/bucket/documents/123/doc.pdf"
  #
  # @example Upload string data
  #   data = StringIO.new("Hello, World!")
  #   url = S3Service.upload("files/hello.txt", data, content_type: "text/plain")
  #
  def self.upload(key, data, options = {})
    return upload_local(key, data) if AWS_S3_BLOCK

    object = create_object key
    options = options.merge(
      body: data,
      cache_control: "public, max-age=0, must-revalidate"
    )
    object.put(options)
    object.public_url
  end

  # Uploads data to local filesystem (fallback when S3 is disabled).
  #
  # @param key [String] The file path relative to Rails.root/s3 directory
  # @param data [String, IO] The data to write to the file
  # @return [String] The absolute local file path
  #
  def upload_local(key, data)
    url = Rails.root.join("s3", key)
    FileUtils.mkdir_p(File.dirname(url))
    File.binwrite(url, data)
    url.to_s
  end

  def self.url_for(key)
    create_object(key).public_url
  end

  # Deletes an object from S3. No-op when AWS_S3_BLOCK is true.
  #
  # @param key [String] The S3 object key (e.g. "uploads/settings/logo.png")
  #
  def self.delete_object(key)
    return if AWS_S3_BLOCK

    create_object(key).delete
  end
end

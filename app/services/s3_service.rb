# frozen_string_literal: true

require 'aws-sdk-s3'

class S3Service
  def self.create_object(key)
    ::Aws::S3::Resource
      .new(region: ENV.fetch('AWS_REGION'))
      .bucket(ENV.fetch('AWS_S3_BUCKET_NAME'))
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
    bucket = uri.host.split('.').first
    key = URI.decode_www_form_component(uri.path[1..]) # Decode URL-encoded characters

    # Initialize the S3 client
    s3_client = Aws::S3::Client.new(
      region: ENV.fetch('AWS_REGION', 'us-east-1'),
      access_key_id: ENV.fetch('AWS_ACCESS_KEY_ID', nil),
      secret_access_key: ENV.fetch('AWS_SECRET_ACCESS_KEY', nil)
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

  #
  # Upload data to the specified resource by key
  #
  # @param [String] key Key of the object. Usually represents the full path inside a bucket
  # @param [IO|StringIO] data The data to be uploaded
  # @param [Hash] options Additional options to be passed to Aws::S3::Object#put method
  #
  # @return [String] The final URL of the uploaded object
  #
  def self.upload(key, data, options = {})
    object = create_object key
    options = options.merge(
      body: data,
      cache_control: 'public, max-age=0, must-revalidate'
    )
    object.put(options)
    object.public_url
  end

  def self.url_for(key)
    create_object(key).public_url
  end
end

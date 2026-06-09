# frozen_string_literal: true

# Indicates whether S3 access is blocked, based on the environment variable `AWS_S3_BLOCK`.
AWS_S3_BLOCK = ENV.fetch("AWS_S3_BLOCK", "false").in?(%w(true 1))

# Optional S3 endpoint override for local development (minio, localstack).
# When set, points the AWS SDK's S3 client at the alternate endpoint and
# enables path-style addressing (required for non-AWS endpoints whose hosts
# don't support virtual-hosted-style bucket subdomains).
if (s3_endpoint = ENV["AWS_ENDPOINT_URL_S3"].presence)
  Aws.config[:s3] = {
    endpoint: s3_endpoint,
    force_path_style: true
  }
end

# frozen_string_literal: true

require "lt/google/api/auth/cli"

class UnitParseJob < ApplicationJob
  include ResqueJob
  include RetryDelayed

  queue_as :default

  def perform(id_or_url, options = {})
    url =
      if id_or_url.is_a?(String)
        id_or_url
      else
        Resource.units.find(id_or_url).links.dig("source", "gdoc", "url")
      end

    form = UnitForm.new({ link: url }, import_retry: true)
    res = if form.save
            { ok: true, link: url, model: form.unit }
          else
            { ok: false, link: url, errors: form.errors[:link] }
          end
    store_result(res, options)
  rescue StandardError => e
    res = { ok: false, link: id_or_url, errors: [e.message] }
    store_result(res, options)
  end
end

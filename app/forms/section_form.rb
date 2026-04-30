# frozen_string_literal: true

class SectionForm < ImportForm
  attr_reader :section

  def save
    super do
      service = SectionBuildService.new(google_credentials, import_retry: options[:import_retry])
      @section = service.build_for(link)
      @service_errors.push(*service.errors.uniq)
    end
  end
end

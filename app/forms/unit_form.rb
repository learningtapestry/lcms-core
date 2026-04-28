# frozen_string_literal: true

class UnitForm < ImportForm
  attr_reader :unit

  def save
    super do
      service = UnitBuildService.new(google_credentials, import_retry: options[:import_retry])
      @unit = service.build_for(link)
      @service_errors.push(*service.errors.uniq)
    end
  end
end

# frozen_string_literal: true

# Rails resets ActiveSupport::CurrentAttributes around each request and job, but
# not between RSpec examples. Reset them so per-request state (e.g. Current's
# DocTemplate memo) never leaks across examples.
RSpec.configure do |config|
  config.before(:each) { Current.reset }
end

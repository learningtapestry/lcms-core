# frozen_string_literal: true

require "rails_helper"

RSpec.describe RetryDelayed do
  include ActiveJob::TestHelper

  let(:test_class) do
    Class.new(ApplicationJob) do
      include RetryDelayed

      queue_as :default

      def perform(should_fail: false, error_message: "something went wrong")
        raise StandardError, error_message if should_fail
      end
    end
  end

  around do |example|
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = original_adapter
  end

  before { stub_const("TestRetryDelayedJob", test_class) }

  describe "retry on StandardError" do
    it "retries up to #{RetryDelayed::RETRY_DELAYS.size} times" do
      perform_enqueued_jobs(only: TestRetryDelayedJob) do
        TestRetryDelayedJob.perform_later(should_fail: true)
      rescue StandardError
        # Expected after all retries exhausted
      end

      # 1 original + 4 retries = 5 attempts
      expect(performed_jobs.count { |j| j["job_class"] == "TestRetryDelayedJob" }).to eq(5)
    end
  end

  describe "PAGE_BREAK script errors are discarded" do
    it "does not retry when message contains both 'Script error message' and 'PAGE_BREAK'" do
      error_message = "Script error message: PAGE_BREAK not allowed"

      perform_enqueued_jobs(only: TestRetryDelayedJob) do
        TestRetryDelayedJob.perform_later(should_fail: true, error_message: error_message)
      end

      # Discarded after 1 attempt — no retries
      expect(performed_jobs.count { |j| j["job_class"] == "TestRetryDelayedJob" }).to eq(1)
    end

    it "still retries when only 'PAGE_BREAK' is present without 'Script error message'" do
      error_message = "PAGE_BREAK encountered"

      perform_enqueued_jobs(only: TestRetryDelayedJob) do
        TestRetryDelayedJob.perform_later(should_fail: true, error_message: error_message)
      rescue StandardError
        # Expected after retries exhausted
      end

      expect(performed_jobs.count { |j| j["job_class"] == "TestRetryDelayedJob" }).to eq(5)
    end
  end

  describe "delay calculation" do
    it "uses escalating delays" do
      expect(RetryDelayed::RETRY_DELAYS).to eq([30.seconds, 1.minute, 3.minutes, 7.minutes])
    end
  end
end

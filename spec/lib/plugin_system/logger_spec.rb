# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PluginSystem.logger" do
  before do
    # Reset cached logger between tests
    PluginSystem.instance_variable_set(:@logger, nil)
  end

  after do
    PluginSystem.instance_variable_set(:@logger, nil)
  end

  describe ".logger" do
    it "returns a BroadcastLogger" do
      expect(PluginSystem.logger).to be_a(ActiveSupport::BroadcastLogger)
    end

    it "memoizes the logger instance" do
      logger1 = PluginSystem.logger
      logger2 = PluginSystem.logger

      expect(logger1).to be(logger2)
    end

    it "includes Rails.logger in broadcasts" do
      expect(PluginSystem.logger.broadcasts).to include(Rails.logger)
    end

    it "writes to Rails.logger" do
      expect(Rails.logger).to receive(:info).with("[Test] message")

      PluginSystem.logger.info "[Test] message"
    end

    context "in development environment" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
      end

      it "includes stdout logger" do
        stdout_logger = PluginSystem.logger.broadcasts.find { |l| l.is_a?(ActiveSupport::Logger) }
        expect(stdout_logger).not_to be_nil
      end

      it "writes to stdout" do
        expect { PluginSystem.logger.info "[Test] stdout message" }.to output(/\[Test\] stdout message/).to_stdout
      end
    end

    context "in test environment" do
      it "includes stdout logger" do
        stdout_logger = PluginSystem.logger.broadcasts.find { |l| l.is_a?(ActiveSupport::Logger) }
        expect(stdout_logger).not_to be_nil
      end
    end

    context "in production environment without PLUGIN_DEBUG" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("PLUGIN_DEBUG").and_return(nil)
        allow(ENV).to receive(:fetch).and_call_original
      end

      it "does not include stdout logger" do
        # Only Rails.logger should be in broadcasts
        expect(PluginSystem.logger.broadcasts.size).to eq(1)
        expect(PluginSystem.logger.broadcasts.first).to eq(Rails.logger)
      end
    end

    context "in production environment with PLUGIN_DEBUG=1" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("PLUGIN_DEBUG").and_return("1")
        allow(ENV).to receive(:fetch).and_call_original
      end

      it "includes stdout logger" do
        stdout_logger = PluginSystem.logger.broadcasts.find { |l| l.is_a?(ActiveSupport::Logger) }
        expect(stdout_logger).not_to be_nil
      end
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

describe ErrorMessage, type: :controller do
  controller(ApplicationController) { include ErrorMessage }

  describe "#error_message_for" do
    context "when the message is shorter than the maximum character limit" do
      let(:error) { StandardError.new("Short error message") }

      subject { controller.send(:error_message_for, error) }

      it "returns the original message" do
        expect(subject).to eq "Short error message"
      end
    end

    context "when the message is longer than the maximum character limit" do
      let(:long_message) { "a" * (FLASH_MESSAGE_MAX_CHAR + 100) }
      let(:error) { StandardError.new(long_message) }

      subject { controller.send(:error_message_for, error) }

      it "returns a truncated message" do
        expect(subject.length).to eq FLASH_MESSAGE_MAX_CHAR
      end

      it "returns the last characters of the message" do
        expect(subject).to eq long_message.slice(-FLASH_MESSAGE_MAX_CHAR..-1)
      end
    end

    context "when message with HTML is longer than max" do
      # HTML tags are only stripped when message exceeds FLASH_MESSAGE_MAX_CHAR
      let(:base_content) { "a" * (FLASH_MESSAGE_MAX_CHAR + 50) }
      let(:html_message) { "<p>#{base_content}</p>" }
      let(:error) { StandardError.new(html_message) }

      subject { controller.send(:error_message_for, error) }

      it "strips HTML tags from the message" do
        expect(subject).not_to include("<p>")
        expect(subject).not_to include("</p>")
      end
    end

    context "when stripped message is still longer than max" do
      let(:long_html_message) { "<p>#{"a" * (FLASH_MESSAGE_MAX_CHAR + 100)}</p>" }
      let(:error) { StandardError.new(long_html_message) }

      subject { controller.send(:error_message_for, error) }

      it "returns a truncated stripped message" do
        expect(subject.length).to eq FLASH_MESSAGE_MAX_CHAR
        expect(subject).not_to include("<p>")
      end
    end

    context "when short message contains HTML" do
      # Short messages are returned as-is without HTML stripping
      let(:html_message) { "<p>Short</p>" }
      let(:error) { StandardError.new(html_message) }

      subject { controller.send(:error_message_for, error) }

      it "returns the original message with HTML" do
        expect(subject).to eq html_message
      end
    end
  end
end

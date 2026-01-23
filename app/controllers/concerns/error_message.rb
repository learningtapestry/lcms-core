# frozen_string_literal: true

module ErrorMessage
  private

  def error_message_for(ex)
    return ex.message if ex.message.length < FLASH_MESSAGE_MAX_CHAR

    message = ActionController::Base.helpers.strip_tags(ex.message)
    return message if message.length < FLASH_MESSAGE_MAX_CHAR

    message.slice(-FLASH_MESSAGE_MAX_CHAR..-1)
  end
end

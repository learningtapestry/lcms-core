# frozen_string_literal: true

class WelcomeController < ApplicationController
  skip_before_action :authenticate_user!, if: -> { request.path.index('oauth2callback').present? }

  OAUTH_REFERER = 'https://accounts.google.com/'
  OAUTH_MESSAGE = 'Copy this code and use it to continue authorization'

  def index; end

  def oauth2callback
    head(:not_found) && return unless request.referer == OAUTH_REFERER

    render json: { text: OAUTH_MESSAGE, code: params[:code] }
  end
end

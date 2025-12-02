# frozen_string_literal: true

require 'rails_helper'

describe Admin::WelcomeController do
  let(:user) { create :admin }

  describe 'GET index' do
    context 'requires admin user' do
      before { get :index }
      it { expect(response).to redirect_to new_user_session_path }
    end

    context 'allow admin' do
      before do
        sign_in user
        get :index
      end

      it { expect(response).to be_successful }
    end
  end
end

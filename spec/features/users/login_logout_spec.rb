# frozen_string_literal: true

require 'rails_helper'

feature 'Login/logout functionality' do
  given(:email) { Faker::Internet.email }
  given(:password) { Faker::Internet.password }
  given!(:admin) { create :admin, email:, password:, password_confirmation: password }

  scenario 'login' do
    visit admin_path
    expect(current_path).to eq new_user_session_path

    fill_in 'email-field', with: email
    fill_in 'password-field', with: password
    click_on 'Log in'
    expect(current_path).to eq admin_path
  end

  scenario 'logout' do
    login_as admin, scope: :user

    visit admin_path
    find(:xpath, "//a[@href='#{destroy_user_session_path}']").click
    expect(current_path).to eq new_user_session_path
  end
end

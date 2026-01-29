# frozen_string_literal: true

require "rails_helper"

feature "Welcome Page" do
  given(:user) { create :user }

  scenario "only authenticated users can access application" do
    visit root_path
    expect(page).to have_text(I18n.t("devise.failure.unauthenticated"))
  end

  scenario "visit welcome page and see the shout out panel" do
    login_as user
    visit root_path
    expect(page).to have_css(".container-fluid div#root")
  end
end

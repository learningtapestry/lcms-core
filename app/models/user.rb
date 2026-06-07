# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  access_code            :string
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :inet
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :inet
#  name                   :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  role                   :integer          default("user"), not null
#  sign_in_count          :integer          default(0), not null
#  survey                 :hstore
#  unconfirmed_email      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
require "devise"

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :confirmable,
         :recoverable, :rememberable, :trackable, :validatable

  enum :role, { admin: 1, user: 0 }

  validates_presence_of :access_code, on: :create, unless: :admin?
  validates_presence_of :email, :role
  validate :access_code_valid?, on: :create, unless: :admin?

  def generate_password
    pwd = Devise.friendly_token.first(20)
    self.password = pwd
    self.password_confirmation = pwd
  end

  private

  def access_code_valid?
    return false if AccessCode.by_code(access_code.to_s).exists?

    errors.add :access_code, "not found"
  end

  protected

  # NOTE: temporary disable confirmable due to issues with server setup
  def confirmation_required?
    false
  end
end

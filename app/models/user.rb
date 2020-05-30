# frozen_string_literal: true

class User < ApplicationRecord
  has_many :user_installations
  has_many :installations, through: :user_installations
  has_many :coverage_checks, through: :installations

  validates :uid, :email, :name, :token, presence: true

  def self.from_omniauth(auth_hash)
    user = find_or_initialize_by(uid: auth_hash[:uid])
    user.assign_attributes(
      name: auth_hash.dig("info", "nickname"),
      email: auth_hash.dig("info", "email"),
      token: auth_hash.dig("credentials", "token")
    )
    user.save!
    user
  end

  TOKEN_KEY = ENV.fetch("USER_TOKEN_ENCRYPTION_KEY").freeze

  def token=(new_token)
    cipher = OpenSSL::Cipher::AES256.new(:CBC).encrypt
    cipher.key = TOKEN_KEY
    iv = cipher.random_iv
    super(Base64.encode64(iv + cipher.update(new_token) + cipher.final))
  end

  def token
    return if super.blank?

    decoded_base64 = Base64.decode64(super)
    cipher = OpenSSL::Cipher::AES256.new(:CBC).decrypt
    cipher.key = TOKEN_KEY
    cipher.iv = decoded_base64[0..15]
    cipher.update(decoded_base64[16..-1]) + cipher.final
  end
end

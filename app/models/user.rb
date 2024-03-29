# frozen_string_literal: true

class User < ApplicationRecord
  has_many :user_installations
  has_many :installations, through: :user_installations
  has_many :coverage_checks, through: :installations

  validates :uid, :name, :token, presence: true

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
  API_TOKEN_IV = Base64.decode64("nPDwkL9ckWPJQZevoe+efg==\n") # deterministic iv

  def reset_api_token
    SecureRandom.hex(16).tap do |new_token|
      update!(api_token: self.class.encrypt(new_token, TOKEN_KEY, API_TOKEN_IV))
    end
  end

  def self.find_by_api_token(raw_token)
    super(encrypt(raw_token, TOKEN_KEY, API_TOKEN_IV))
  end

  def token=(new_token)
    super(self.class.encrypt(new_token, TOKEN_KEY))
  end

  def token
    return if super.blank?

    self.class.decrypt(super)
  end

  def analytics_id
    "U#{id}"
  end

  def self.encrypt(value, key = TOKEN_KEY, stored_iv = nil)
    cipher = OpenSSL::Cipher.new("AES-256-CBC").encrypt
    cipher.key = key
    iv = stored_iv || cipher.random_iv
    Base64.encode64(iv + cipher.update(value) + cipher.final)
  end

  def self.decrypt(value, key = TOKEN_KEY)
    decoded_base64 = Base64.decode64(value)
    cipher = OpenSSL::Cipher.new("AES-256-CBC").decrypt
    cipher.key = key
    cipher.iv = decoded_base64[0..15]
    cipher.update(decoded_base64[16..]) + cipher.final
  end
end

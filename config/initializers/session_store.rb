# Be sure to restart your server when you modify this file.

if defined?(ActionDispatch::Session::EncryptedCookieStore)
  JrubyRails::Application.config.session_store :encrypted_cookie_store, key: '_jruby_rails_session'
else
  JrubyRails::Application.config.session_store :cookie_store, key: '_jruby_rails_session'
  Rails.logger.warn "Not using EncryptedCookieStore..."
end

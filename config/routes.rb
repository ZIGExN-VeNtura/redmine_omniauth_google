# frozen_string_literal: true

Rails.application.routes.draw do
  get 'oauth_google', to: 'oauth_google#redirect_to_google', as: :oauth_google
  get 'oauth_google/callback', to: 'oauth_google#callback', as: :oauth_google_callback
end

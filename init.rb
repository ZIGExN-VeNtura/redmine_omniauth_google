# frozen_string_literal: true

require_relative 'lib/redmine_omniauth_google'

Redmine::Plugin.register :redmine_omniauth_google do
  name 'Redmine Google OAuth Login'
  author 'Ventura Development Team'
  description 'Plugin cho phép đăng nhập Redmine bằng tài khoản Google OAuth2'
  version '1.0.0'
  url 'https://github.com/ZIGExN-VeNtura/redmine_omniauth_google'
  author_url 'https://github.com/orgs/ZIGExN-VeNtura/teams/r-and-d'

  requires_redmine version_or_higher: '5.0'

  settings default: {
    'client_id' => '',
    'client_secret' => '',
    'allowed_domains' => '',
    'enabled' => '0'
  }, partial: 'settings/google_oauth_settings'
end

Rails.application.config.after_initialize do
  require_relative 'lib/redmine_omniauth_google/hooks'
end

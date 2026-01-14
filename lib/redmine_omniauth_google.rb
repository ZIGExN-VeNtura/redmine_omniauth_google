# frozen_string_literal: true

module RedmineOmniauthGoogle
  def self.settings
    Setting.plugin_redmine_omniauth_google || {}
  end

  def self.enabled?
    settings['enabled'].to_s == '1' &&
      settings['client_id'].present? &&
      settings['client_secret'].present?
  end
end

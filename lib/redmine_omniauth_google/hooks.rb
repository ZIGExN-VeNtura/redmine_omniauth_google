# frozen_string_literal: true

module RedmineOmniauthGoogle
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_account_login_bottom, partial: 'hooks/google_login_button'
  end
end

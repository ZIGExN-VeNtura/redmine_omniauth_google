# frozen_string_literal: true

require 'net/http'
require 'json'
require 'securerandom'

class OauthGoogleController < ApplicationController
  skip_before_action :check_if_login_required
  skip_before_action :verify_authenticity_token, only: [:callback]

  # Google OAuth2 endpoints
  GOOGLE_AUTH_URL = 'https://accounts.google.com/o/oauth2/v2/auth'
  GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token'
  GOOGLE_USERINFO_URL = 'https://www.googleapis.com/oauth2/v3/userinfo'

  def redirect_to_google
    unless plugin_enabled?
      flash[:error] = l(:notice_google_oauth_disabled)
      redirect_to signin_path
      return
    end

    # Generate state for CSRF protection
    state = SecureRandom.hex(16)
    session[:oauth_state] = state
    session[:oauth_back_url] = params[:back_url]

    auth_params = {
      client_id: settings['client_id'],
      redirect_uri: oauth_google_callback_url,
      response_type: 'code',
      scope: 'openid email profile',
      state: state,
      access_type: 'online',
      prompt: 'select_account'
    }

    redirect_to "#{GOOGLE_AUTH_URL}?#{auth_params.to_query}", allow_other_host: true
  end

  def callback
    unless plugin_enabled?
      flash[:error] = l(:notice_google_oauth_disabled)
      redirect_to signin_path
      return
    end

    # Verify state to prevent CSRF
    if params[:state].blank? || params[:state] != session[:oauth_state]
      flash[:error] = l(:notice_google_oauth_invalid_state)
      redirect_to signin_path
      return
    end

    session.delete(:oauth_state)

    if params[:error].present?
      flash[:error] = l(:notice_google_oauth_denied)
      redirect_to signin_path
      return
    end

    if params[:code].blank?
      flash[:error] = l(:notice_google_oauth_no_code)
      redirect_to signin_path
      return
    end

    # Exchange code for access token
    token_data = exchange_code_for_token(params[:code])
    unless token_data && token_data['access_token']
      flash[:error] = l(:notice_google_oauth_token_error)
      redirect_to signin_path
      return
    end

    # Get user info from Google
    user_info = get_user_info(token_data['access_token'])
    unless user_info && user_info['email']
      flash[:error] = l(:notice_google_oauth_userinfo_error)
      redirect_to signin_path
      return
    end

    email = user_info['email'].downcase

    # Check if email domain is allowed
    unless domain_allowed?(email)
      flash[:error] = l(:notice_google_oauth_domain_not_allowed)
      redirect_to signin_path
      return
    end

    # Find user by email in Redmine
    user = User.find_by_mail(email)
    unless user
      flash[:error] = l(:notice_google_oauth_user_not_found)
      redirect_to signin_path
      return
    end

    # Check if user is active
    unless user.active?
      if user.registered?
        flash[:error] = l(:notice_account_not_activated_yet, url: activation_email_path)
      else
        flash[:error] = l(:notice_account_locked)
      end
      redirect_to signin_path
      return
    end

    # Handle 2FA if enabled
    if user.twofa_active?
      setup_twofa_session(user)
      twofa = Redmine::Twofa.for_user(user)
      if twofa.send_code(controller: 'account', action: 'twofa')
        flash[:notice] = l('twofa_code_sent')
      end
      redirect_to account_twofa_confirm_path
      return
    end

    # Successfully authenticate user
    successful_authentication(user)
  end

  private

  def settings
    Setting.plugin_redmine_omniauth_google || {}
  end

  def plugin_enabled?
    settings['enabled'].to_s == '1' &&
      settings['client_id'].present? &&
      settings['client_secret'].present?
  end

  def domain_allowed?(email)
    allowed_domains = settings['allowed_domains'].to_s.strip
    return true if allowed_domains.blank?

    email_domain = email.split('@').last.downcase
    domains = allowed_domains.split(',').map { |d| d.strip.downcase.delete_prefix('@') }

    domains.include?(email_domain)
  end

  def exchange_code_for_token(code)
    uri = URI(GOOGLE_TOKEN_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request.set_form_data(
      code: code,
      client_id: settings['client_id'],
      client_secret: settings['client_secret'],
      redirect_uri: oauth_google_callback_url,
      grant_type: 'authorization_code'
    )

    response = http.request(request)
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.error "Google OAuth token error: #{response.body}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "Google OAuth token exception: #{e.message}"
    nil
  end

  def get_user_info(access_token)
    uri = URI(GOOGLE_USERINFO_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.path)
    request['Authorization'] = "Bearer #{access_token}"

    response = http.request(request)
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.error "Google OAuth userinfo error: #{response.body}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "Google OAuth userinfo exception: #{e.message}"
    nil
  end

  def setup_twofa_session(user)
    token = Token.create(user: user, action: 'twofa_session')
    session[:twofa_session_token] = token.value
    session[:twofa_tries_counter] = 1
    session[:twofa_back_url] = session[:oauth_back_url]
    session[:twofa_autologin] = nil
  end

  def successful_authentication(user)
    logger.info "Successful Google OAuth authentication for '#{user.login}' from #{request.remote_ip} at #{Time.now.utc}"

    self.logged_user = user
    user.update_last_login_on!

    call_hook(:controller_account_success_authentication_after, { user: user })

    back_url = session.delete(:oauth_back_url)
    redirect_back_or_default(back_url.presence || my_page_path)
  end
end

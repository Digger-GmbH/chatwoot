class Integrations::Shopify::AccessTokenService
  TOKEN_EXPIRY_BUFFER = 1.minute

  pattr_initialize [:hook!]

  def access_token
    return hook.access_token if token_valid?
    return refresh_access_token if refresh_token.present?

    hook.access_token
  end

  private

  def refresh_access_token
    response = HTTParty.post(
      token_url,
      headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' },
      body: {
        client_id: client_id,
        client_secret: client_secret,
        grant_type: 'refresh_token',
        refresh_token: refresh_token
      }.to_json
    )

    return fallback_access_token unless response.success?

    persist_tokens(response.parsed_response)
    hook.access_token
  rescue StandardError => e
    Rails.logger.error("Shopify token refresh failed for hook #{hook.id}: #{e.message}")
    fallback_access_token
  end

  def persist_tokens(token_data)
    raise ArgumentError, 'Missing access token in Shopify token response' if token_data['access_token'].blank?

    current_settings = hook_settings
    updated_settings = current_settings.merge(
      scope: token_data['scope'] || current_settings[:scope],
      expires_in: token_data['expires_in'] || current_settings[:expires_in],
      expires_on: expires_on(token_data['expires_in']),
      refresh_token: token_data['refresh_token'] || current_settings[:refresh_token],
      refresh_token_expires_in: token_data['refresh_token_expires_in'] || current_settings[:refresh_token_expires_in],
      refresh_token_expires_on: expires_on(token_data['refresh_token_expires_in'],
                                           fallback: current_settings[:refresh_token_expires_on])
    ).compact

    hook.update!(
      access_token: token_data['access_token'],
      settings: updated_settings
    )
  end

  def token_valid?
    # Legacy non-expiring offline tokens have no expiry or refresh metadata.
    return true if expires_on_value.blank? && refresh_token.blank?
    return false if expires_on_value.blank?

    Time.zone.parse(expires_on_value).utc > (Time.current.utc + TOKEN_EXPIRY_BUFFER)
  rescue StandardError
    false
  end

  def refresh_token
    hook_settings[:refresh_token]
  end

  def expires_on_value
    hook_settings[:expires_on]
  end

  def hook_settings
    hook.settings.to_h.with_indifferent_access
  end

  def expires_on(expires_in, fallback: nil)
    return fallback if expires_in.blank?

    (Time.current.utc + expires_in.to_i.seconds).to_s
  end

  def token_url
    "https://#{hook.reference_id}/admin/oauth/access_token"
  end

  def client_id
    GlobalConfigService.load('SHOPIFY_CLIENT_ID', nil)
  end

  def client_secret
    GlobalConfigService.load('SHOPIFY_CLIENT_SECRET', nil)
  end

  def fallback_access_token
    hook.reload.access_token
  rescue StandardError
    hook.access_token
  end
end

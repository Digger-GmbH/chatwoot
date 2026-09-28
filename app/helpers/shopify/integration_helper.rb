module Shopify::IntegrationHelper
  REQUIRED_SCOPES = %w[read_customers read_orders read_fulfillments].freeze

  # Generates a signed JWT token for Shopify integration
  #
  # @param account_id [Integer] The account ID to encode in the token
  # @return [String, nil] The encoded JWT token or nil if client secret is missing
  def generate_shopify_token(account_id)
    secret = shopify_client_secret(Account.find_by(id: account_id))
    return if secret.blank?

    JWT.encode(token_payload(account_id), secret, 'HS256')
  rescue StandardError => e
    Rails.logger.error("Failed to generate Shopify token: #{e.message}")
    nil
  end

  def token_payload(account_id)
    {
      sub: account_id,
      iat: Time.current.to_i
    }
  end

  # Verifies and decodes a Shopify JWT token
  #
  # @param token [String] The JWT token to verify
  # @return [Integer, nil] The account ID from the token or nil if invalid
  def verify_shopify_token(token)
    return if token.blank?

    account = account_from_unverified_token(token)
    secret = shopify_client_secret(account)
    return if secret.blank?

    decode_token(token, secret)
  end

  private

  def shopify_credentials(account = nil)
    Shopify::Credentials.for(account)
  end

  def shopify_client_id(account = nil)
    shopify_credentials(account).client_id
  end

  def shopify_client_secret(account = nil)
    shopify_credentials(account).client_secret
  end

  # Backward-compatible aliases used by existing controllers/specs.
  def client_id
    shopify_client_id
  end

  def client_secret
    shopify_client_secret
  end

  def account_from_unverified_token(token)
    payload = JWT.decode(token, nil, false).first
    Account.find_by(id: payload['sub'])
  rescue StandardError
    nil
  end

  def decode_token(token, secret)
    JWT.decode(
      token,
      secret,
      true,
      {
        algorithm: 'HS256',
        verify_expiration: true
      }
    ).first['sub']
  rescue StandardError => e
    Rails.logger.error("Unexpected error verifying Shopify token: #{e.message}")
    nil
  end
end

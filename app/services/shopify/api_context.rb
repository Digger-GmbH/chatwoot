class Shopify::ApiContext
  API_VERSION = ShopifyAPI::LATEST_SUPPORTED_ADMIN_VERSION
  class ConfigurationError < StandardError; end

  def self.setup!(account: nil)
    credentials = Shopify::Credentials.for(account)
    raise ConfigurationError, 'Shopify API credentials are unavailable' unless credentials.configured?

    ShopifyAPI::Context.setup(
      api_key: credentials.client_id,
      api_secret_key: credentials.client_secret,
      api_version: API_VERSION,
      scope: Shopify::IntegrationHelper::REQUIRED_SCOPES.join(','),
      is_embedded: true,
      is_private: false
    )
  end
end

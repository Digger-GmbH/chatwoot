class Shopify::Credentials
  pattr_initialize [:account]

  def self.for(account = nil)
    new(account: account)
  end

  def client_id
    account_credential&.client_id.presence || global_client_id
  end

  def client_secret
    account_credential&.client_secret.presence || global_client_secret
  end

  def configured?
    client_id.present? && client_secret.present?
  end

  def account_configured?
    account_credential.present?
  end

  def source
    return :account if account_configured?

    :global if global_client_id.present? && global_client_secret.present?
  end

  private

  def account_credential
    return if account.blank?

    @account_credential ||= account.shopify_app_credential
  end

  def global_client_id
    @global_client_id ||= GlobalConfigService.load('SHOPIFY_CLIENT_ID', nil)
  end

  def global_client_secret
    @global_client_secret ||= GlobalConfigService.load('SHOPIFY_CLIENT_SECRET', nil)
  end
end

class Api::V1::Accounts::Integrations::ShopifyController < Api::V1::Accounts::Integrations::BaseController
  include Shopify::IntegrationHelper
  before_action :setup_shopify_context, only: [:orders]
  before_action :fetch_hook, except: [:auth, :show_credentials, :update_credentials, :destroy_credentials]
  before_action :authorize_credential_update, only: [:update_credentials]
  before_action :authorize_credential_destroy, only: [:destroy_credentials]
  before_action :check_authorization, only: [:destroy]
  before_action :validate_contact, only: [:orders]

  def auth
    shop_domain = params[:shop_domain]
    return render json: { error: 'Shop domain is required' }, status: :unprocessable_entity if shop_domain.blank?

    credentials = shopify_credentials(Current.account)
    unless credentials.configured?
      return render json: { error: 'Shopify OAuth client credentials are not configured for this account' },
                    status: :unprocessable_entity
    end

    state = generate_shopify_token(Current.account.id)
    return render json: { error: 'Unable to start Shopify authorization' }, status: :unprocessable_entity if state.blank?

    auth_url = "https://#{shop_domain}/admin/oauth/authorize?"
    auth_url += URI.encode_www_form(
      client_id: credentials.client_id,
      scope: REQUIRED_SCOPES.join(','),
      redirect_uri: redirect_uri,
      state: state
    )

    render json: { redirect_url: auth_url }
  end

  def show_credentials
    credentials = shopify_credentials(Current.account)
    credential = Current.account.shopify_app_credential

    render json: {
      client_id: credential&.client_id.to_s,
      client_secret_configured: credential&.client_secret.present?,
      source: credentials.source,
      global_fallback_available: global_credentials_available?
    }
  end

  def update_credentials
    credential = Current.account.shopify_app_credential || Current.account.build_shopify_app_credential
    attrs = credential_params.to_h.compact_blank
    attrs.delete('client_secret') if attrs['client_secret'].blank? && credential.persisted?

    if credential.update(attrs)
      render json: {
        client_id: credential.client_id,
        client_secret_configured: credential.client_secret.present?,
        source: :account,
        global_fallback_available: global_credentials_available?
      }
    else
      render json: { error: credential.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def destroy_credentials
    Current.account.shopify_app_credential&.destroy!
    head :no_content
  end

  def orders
    customers = fetch_customers
    return render json: { orders: [] } if customers.empty?

    orders = fetch_orders(customers.first['id'])
    render json: { orders: orders }
  rescue ShopifyAPI::Errors::HttpResponseError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    @hook.destroy!
    head :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def credential_params
    params.permit(:client_id, :client_secret)
  end

  def authorize_credential_update
    authorize(:hook, :update?)
  end

  def authorize_credential_destroy
    authorize(:hook, :destroy?)
  end

  def global_credentials_available?
    GlobalConfigService.load('SHOPIFY_CLIENT_ID', nil).present? &&
      GlobalConfigService.load('SHOPIFY_CLIENT_SECRET', nil).present?
  end

  def redirect_uri
    "#{ENV.fetch('FRONTEND_URL', '')}/shopify/callback"
  end

  def contact
    @contact ||= Current.account.contacts.find_by(id: params[:contact_id])
  end

  def fetch_hook
    @hook = Integrations::Hook.find_by!(account: Current.account, app_id: 'shopify')
  end

  def fetch_customers
    query = []
    query << "email:#{contact.email}" if contact.email.present?
    query << "phone:#{contact.phone_number}" if contact.phone_number.present?

    shopify_client.get(
      path: 'customers/search.json',
      query: {
        query: query.join(' OR '),
        fields: 'id,email,phone'
      }
    ).body['customers'] || []
  end

  def fetch_orders(customer_id)
    orders = shopify_client.get(
      path: 'orders.json',
      query: {
        customer_id: customer_id,
        status: 'any',
        fields: 'id,email,created_at,total_price,currency,fulfillment_status,financial_status'
      }
    ).body['orders'] || []

    orders.map do |order|
      order.merge('admin_url' => "https://#{@hook.reference_id}/admin/orders/#{order['id']}")
    end
  end

  def setup_shopify_context
    credentials = shopify_credentials(Current.account)
    return unless credentials.configured?

    ShopifyAPI::Context.setup(
      api_key: credentials.client_id,
      api_secret_key: credentials.client_secret,
      api_version: '2025-01'.freeze,
      scope: REQUIRED_SCOPES.join(','),
      is_embedded: true,
      is_private: false
    )
  end

  def shopify_session
    access_token = Integrations::Shopify::AccessTokenService.new(hook: @hook).access_token
    ShopifyAPI::Auth::Session.new(shop: @hook.reference_id, access_token: access_token)
  end

  def shopify_client
    @shopify_client ||= ShopifyAPI::Clients::Rest::Admin.new(session: shopify_session)
  end

  def validate_contact
    return unless contact.blank? || (contact.email.blank? && contact.phone_number.blank?)

    render json: { error: 'Contact information missing' },
           status: :unprocessable_entity
  end
end

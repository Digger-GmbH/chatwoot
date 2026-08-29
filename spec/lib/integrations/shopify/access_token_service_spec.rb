require 'rails_helper'

describe Integrations::Shopify::AccessTokenService do
  let(:account) { create(:account) }
  let(:shop) { 'test-store.myshopify.com' }
  let(:client_id) { 'shopify_client_id' }
  let(:client_secret) { 'shopify_client_secret' }
  let(:token_url) { "https://#{shop}/admin/oauth/access_token" }

  before do
    allow(GlobalConfigService).to receive(:load).and_call_original
    allow(GlobalConfigService).to receive(:load).with('SHOPIFY_CLIENT_ID', nil).and_return(client_id)
    allow(GlobalConfigService).to receive(:load).with('SHOPIFY_CLIENT_SECRET', nil).and_return(client_secret)
  end

  describe '#access_token' do
    context 'when access token is still valid' do
      let(:hook) do
        create(
          :integrations_hook,
          :shopify,
          account: account,
          access_token: 'valid_access_token',
          reference_id: shop,
          settings: {
            refresh_token: 'refresh_token',
            scope: 'read_customers,read_orders',
            expires_on: 30.minutes.from_now.utc.to_s
          }
        )
      end

      it 'returns the current access token without refreshing' do
        stub_request(:post, token_url)
          .to_return(status: 200, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })

        service = described_class.new(hook: hook)

        expect(service.access_token).to eq('valid_access_token')
        expect(WebMock).not_to have_requested(:post, token_url)
      end
    end

    context 'when using a legacy non-expiring token' do
      let(:hook) do
        create(
          :integrations_hook,
          :shopify,
          account: account,
          access_token: 'legacy_access_token',
          reference_id: shop,
          settings: {
            scope: 'read_customers,read_orders'
          }
        )
      end

      it 'returns the stored access token without refreshing' do
        stub_request(:post, token_url)
          .to_return(status: 200, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })

        service = described_class.new(hook: hook)

        expect(service.access_token).to eq('legacy_access_token')
        expect(WebMock).not_to have_requested(:post, token_url)
      end
    end

    context 'when access token is expired and refresh token is present' do
      let(:hook) do
        create(
          :integrations_hook,
          :shopify,
          account: account,
          access_token: 'expired_access_token',
          reference_id: shop,
          settings: {
            refresh_token: 'old_refresh_token',
            scope: 'read_customers,read_orders',
            expires_on: 1.hour.ago.utc.to_s
          }
        )
      end

      it 'refreshes the token and persists new values' do
        stub_request(:post, token_url)
          .with(
            body: {
              client_id: client_id,
              client_secret: client_secret,
              grant_type: 'refresh_token',
              refresh_token: 'old_refresh_token'
            }.to_json
          )
          .to_return(
            status: 200,
            body: {
              access_token: 'new_access_token',
              refresh_token: 'new_refresh_token',
              expires_in: 3600,
              refresh_token_expires_in: 7_776_000,
              scope: 'read_customers,read_orders'
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        service = described_class.new(hook: hook)

        expect(service.access_token).to eq('new_access_token')
        hook.reload
        expect(hook.access_token).to eq('new_access_token')
        expect(hook.settings['refresh_token']).to eq('new_refresh_token')
        expect(hook.settings['expires_in']).to eq(3600)
        expect(hook.settings['expires_on']).to be_present
        expect(hook.settings['refresh_token_expires_in']).to eq(7_776_000)
        expect(hook.settings['refresh_token_expires_on']).to be_present
      end

      it 'falls back to latest persisted token on refresh failure' do
        stub_request(:post, token_url)
          .to_return(status: 401, body: { error: 'invalid_request' }.to_json, headers: { 'Content-Type' => 'application/json' })

        Integrations::Hook.find(hook.id).update!(access_token: 'rotated_access_token')

        service = described_class.new(hook: hook)

        expect(service.access_token).to eq('rotated_access_token')
      end

      it 'does not overwrite the existing token on malformed success response' do
        stub_request(:post, token_url)
          .to_return(
            status: 200,
            body: {
              refresh_token: 'new_refresh_token',
              expires_in: 3600,
              scope: 'read_customers,read_orders'
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        service = described_class.new(hook: hook)

        expect(service.access_token).to eq('expired_access_token')
        hook.reload
        expect(hook.access_token).to eq('expired_access_token')
        expect(hook.settings['refresh_token']).to eq('old_refresh_token')
      end
    end
  end
end

require 'rails_helper'

RSpec.describe Shopify::Credentials do
  let(:account) { create(:account) }

  before do
    allow(GlobalConfigService).to receive(:load).and_call_original
    allow(GlobalConfigService).to receive(:load).with('SHOPIFY_CLIENT_ID', nil).and_return('global-id')
    allow(GlobalConfigService).to receive(:load).with('SHOPIFY_CLIENT_SECRET', nil).and_return('global-secret')
  end

  it 'falls back to global credentials when account credentials are missing' do
    credentials = described_class.for(account)

    expect(credentials.client_id).to eq('global-id')
    expect(credentials.client_secret).to eq('global-secret')
    expect(credentials.source).to eq(:global)
    expect(credentials).to be_configured
  end

  it 'prefers account credentials when present' do
    create(:shopify_app_credential, account: account, client_id: 'account-id', client_secret: 'account-secret')
    credentials = described_class.for(account)

    expect(credentials.client_id).to eq('account-id')
    expect(credentials.client_secret).to eq('account-secret')
    expect(credentials.source).to eq(:account)
  end

  it 'uses global credentials when no account is provided' do
    credentials = described_class.for(nil)

    expect(credentials.client_id).to eq('global-id')
    expect(credentials.source).to eq(:global)
  end
end

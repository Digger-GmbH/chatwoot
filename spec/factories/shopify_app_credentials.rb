FactoryBot.define do
  factory :shopify_app_credential do
    account
    client_id { SecureRandom.hex(8) }
    client_secret { SecureRandom.hex(16) }
  end
end

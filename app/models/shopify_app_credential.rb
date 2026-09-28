# == Schema Information
#
# Table name: shopify_app_credentials
#
#  id            :bigint           not null, primary key
#  client_id     :string           not null
#  client_secret :text             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#
# Indexes
#
#  index_shopify_app_credentials_on_account_id  (account_id) UNIQUE
#
class ShopifyAppCredential < ApplicationRecord
  belongs_to :account

  encrypts :client_secret if Chatwoot.encryption_configured?

  validates :account_id, presence: true, uniqueness: true
  validates :client_id, presence: true
  validates :client_secret, presence: true
end

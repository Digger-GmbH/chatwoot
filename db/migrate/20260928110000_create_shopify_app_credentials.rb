class CreateShopifyAppCredentials < ActiveRecord::Migration[7.1]
  def change
    create_table :shopify_app_credentials do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.string :client_id, null: false
      t.text :client_secret, null: false

      t.timestamps
    end
  end
end

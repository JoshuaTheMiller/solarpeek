# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      # Auth0 identity — the "sub" claim from the JWT
      t.string  :auth0_sub,        null: false
      t.string  :email,            null: false

      # Role — enforced by Pundit policies; stored as a plain string for readability
      t.string  :role,             null: false, default: 'viewer'

      # Query limit — maximum date-range span (in days) for a solar data request.
      # Default is 30 days. Admins/managers can override per user.
      t.integer :query_limit_days, null: false, default: 30

      # Soft-delete via active flag; deactivated users cannot authenticate
      t.boolean :active,           null: false, default: true

      # Invitation tracking
      t.references :invited_by,    null: true,  foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :users, :auth0_sub, unique: true
    add_index :users, :email,     unique: true
    add_index :users, :role
    add_index :users, :active
  end
end

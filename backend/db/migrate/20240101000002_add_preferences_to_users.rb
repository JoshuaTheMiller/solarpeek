# frozen_string_literal: true

class AddPreferencesToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :query_limit_banner_dismissed, :boolean, default: false, null: false
  end
end

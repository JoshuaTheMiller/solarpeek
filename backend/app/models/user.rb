# frozen_string_literal: true

class User < ApplicationRecord
  # ── Roles ────────────────────────────────────────────────────────────────
  # Stored as a string column so values are human-readable in the DB.
  # Role hierarchy: admin > manager > viewer
  enum :role, { viewer: 'viewer', manager: 'manager', admin: 'admin' }, prefix: true

  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :invited_by, class_name: 'User', optional: true
  has_many   :invited_users, class_name: 'User', foreign_key: :invited_by_id,
             dependent: :nullify, inverse_of: :invited_by

  # ── Validations ──────────────────────────────────────────────────────────
  validates :auth0_sub,        presence: true, uniqueness: true
  validates :email,            presence: true, uniqueness: { case_sensitive: false },
                               format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role,             presence: true
  validates :query_limit_days, numericality: { greater_than: 0 }

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :active,   -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # ── Role helpers ──────────────────────────────────────────────────────────

  # Returns true if this user is allowed to invite a user with the given role.
  # Admins can invite anyone. Managers can invite managers and viewers.
  # Viewers cannot invite.
  def can_invite_role?(role_name)
    return true  if role_admin?
    return %w[manager viewer].include?(role_name.to_s) if role_manager?

    false
  end

  # Returns true if this user can deactivate/remove the target user.
  # Admins and managers can deactivate any non-admin user.
  # Nobody can deactivate themselves.
  def can_deactivate?(target_user)
    return false if target_user == self
    return false if target_user.role_admin?

    role_admin? || role_manager?
  end

  # Effective query limit — nil stored in the DB means no limit.
  def effective_query_limit_days
    query_limit_days
  end

  # Returns true if the given date range (in days) fits within this user's limit.
  def within_query_limit?(start_date, end_date)
    days = (end_date.to_date - start_date.to_date).to_i + 1
    days <= query_limit_days
  end
end

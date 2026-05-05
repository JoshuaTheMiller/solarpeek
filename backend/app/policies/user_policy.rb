# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  # ── Actions ────────────────────────────────────────────────────────────────

  # Admins and managers can list users
  def index?  = user.role_admin? || user.role_manager?

  # Admins and managers can view any user; viewers can only view themselves
  def show?   = user.role_admin? || user.role_manager? || user == record

  # Admins and managers can deactivate users (cannot deactivate themselves
  # or other admins — enforced in the User model's #can_deactivate?)
  def destroy?
    user.can_deactivate?(record)
  end

  # Same permission as destroy — reactivation follows deactivation rights
  def reactivate?
    user.role_admin? || user.role_manager?
  end

  # Admins and managers can set query limits on any user
  def query_limit?
    user.role_admin? || user.role_manager?
  end

  # ── Scope ──────────────────────────────────────────────────────────────────
  class Scope < ApplicationPolicy::Scope
    # Admins and managers see all users; viewers only see themselves
    def resolve
      if user.role_admin? || user.role_manager?
        scope.all
      else
        scope.where(id: user.id)
      end
    end
  end
end

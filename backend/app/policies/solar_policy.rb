# frozen_string_literal: true

# The "record" for SolarPolicy is a plain struct holding the parsed query params,
# so Pundit can evaluate authorization before calling the service.
#
# Usage in controller:
#   authorize SolarQuery.new(start_date: ..., end_date: ...), policy_class: SolarPolicy

SolarQuery = Struct.new(:start_date, :end_date, keyword_init: true)

class SolarPolicy < ApplicationPolicy
  # All authenticated, active users may query solar data,
  # subject to their individual query_limit_days.
  def readings?
    return false unless user.active?

    start_d = record.start_date.to_date
    end_d   = record.end_date.to_date

    raise Pundit::NotAuthorizedError, date_order_error if end_d < start_d

    unless user.within_query_limit?(start_d, end_d)
      raise Pundit::NotAuthorizedError, query_limit_error(start_d, end_d)
    end

    true
  end

  private

  def date_order_error
    'end_date must be on or after start_date'
  end

  def query_limit_error(start_d, end_d)
    requested = (end_d - start_d).to_i + 1
    "Query spans #{requested} days but your limit is #{user.query_limit_days} days"
  end
end

# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

# Shared query helpers for users' custom ticket filters (custom views).
module CustomFilterQuery
  # Mirrors Selector::Sql#validate_pre_condition_blank! so only conditions Selector would reject are dropped.
  NO_VALUE_OPERATORS = ['has changed', 'has reached', 'has reached warning', 'is any of', 'is none of', 'is set', 'not set'].freeze

  # Drops conditions that Selector would reject as invalid (a value is required but empty and no
  # pre_condition like current_user / not_set supplies one). One such condition used to make
  # Selector raise and the whole filter come back empty, on every overview push.
  def self.clean_condition(condition)
    return {} if !condition.is_a?(Hash)

    condition.reject { |_name, cond| cond.is_a?(Hash) && unusable?(cond.with_indifferent_access) }
  end

  # ORDER BY for a filter: only real ticket columns, always table-qualified (joins with articles
  # etc. made a bare "created_at" ambiguous), direction only ASC/DESC.
  def self.order_sql(order)
    order     = (order || {}).with_indifferent_access
    column    = Ticket.column_names.include?(order[:by].to_s) ? order[:by] : 'created_at'
    direction = order[:direction].to_s.casecmp('ASC').zero? ? 'ASC' : 'DESC'

    "tickets.#{column} #{direction}"
  end

  def self.unusable?(cond)
    return false if NO_VALUE_OPERATORS.include?(cond[:operator])
    return false if cond[:pre_condition].present? && cond[:pre_condition] != 'specific'

    value = cond[:value]
    (cond[:operator] != 'today' && !cond.key?(:value)) ||
      (value.is_a?(Array) && value.blank?) ||
      (cond[:operator].to_s.start_with?('contains') && value.blank?)
  end
  private_class_method :unusable?
end

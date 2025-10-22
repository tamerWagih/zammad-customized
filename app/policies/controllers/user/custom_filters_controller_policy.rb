# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Controllers::User::CustomFiltersControllerPolicy < ApplicationPolicy
  def index?
    # Any authenticated user can view their own custom filters
    true
  end

  def show?
    # Users can only view their own custom filters
    true
  end

  def create?
    # Any authenticated user can create custom filters
    user.permissions?('ticket.agent') || user.permissions?('ticket.customer')
  end

  def update?
    # Users can only update their own custom filters
    true
  end

  def destroy?
    # Users can only delete their own custom filters
    true
  end

  def prio?
    # Users can only reorder their own custom filters
    true
  end
end

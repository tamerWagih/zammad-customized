# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class Taskbar::Init::TicketStatsUser < Taskbar::Init::Backend
  def data(result)
    result[:ticket_stats_user] = UserPolicy::Scope
      .new(current_user, User.where(id: user_ids))
      .resolve
      .each_with_object({}) do |elem, memo|
        elem.assets(result[:assets])
        # Cache stats for 5 minutes to reduce DB load on page refresh
        memo[elem.id] = Rails.cache.fetch("ticket_stats_user/#{elem.id}/#{current_user.id}", expires_in: 5.minutes) do
          Ticket::Stats.new(current_user: current_user, user_id: elem.id, assets: result[:assets]).list_stats.except(:assets)
        end
      end
    result
  end
end


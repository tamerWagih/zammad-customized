# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

Zammad::Application.routes.draw do
  api_path = Rails.configuration.api_path

  # custom_filter_selectors - isolated selector preview for custom filters only
  match api_path + '/custom_filter_selectors/preview', to: 'custom_filter_selectors#preview', via: :post
end



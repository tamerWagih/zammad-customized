# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

Zammad::Application.routes.draw do
  api_path = Rails.configuration.api_path

  # custom_filter_attributes - safe attribute list for custom filters
  match api_path + '/custom_filter_attributes', to: 'custom_filter_attributes#index', via: :get
end


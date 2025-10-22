# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

Zammad::Application.routes.draw do
  api_path = Rails.configuration.api_path

  # user_custom_filters
  match api_path + '/user_custom_filters',            to: 'user/custom_filters#index',   via: :get
  match api_path + '/user_custom_filters/:id',        to: 'user/custom_filters#show',    via: :get
  match api_path + '/user_custom_filters',            to: 'user/custom_filters#create',  via: :post
  match api_path + '/user_custom_filters/:id',        to: 'user/custom_filters#update',  via: :put
  match api_path + '/user_custom_filters/:id',        to: 'user/custom_filters#destroy', via: :delete
  match api_path + '/user_custom_filters_prio',       to: 'user/custom_filters#prio',    via: :post
end


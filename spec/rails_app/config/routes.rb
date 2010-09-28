Rails.application.routes.draw do
  # Users scope
  devise_for :users
  resource :users, :only => [:edit, :update], :path => 'account'
  root :to => "home#index"
end
Rails.application.routes.draw do
  get 'suggestions/index'

  get 'suggestions/update'

  resources :businesses
  devise_for :users
  root to: 'pages#home'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end

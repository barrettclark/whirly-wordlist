Rails.application.routes.draw do
  get 'solver/index'
  post 'solver/letters'
  root 'solver#index'
end

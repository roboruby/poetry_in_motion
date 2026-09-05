Rails.application.routes.draw do
  mount Poetry::Ui::Engine => "/poetry" # llms.txt + llms-full.txt (agent-facing docs)

  root "chats#index"

  resources :chats, only: %i[index create show destroy] do
    resources :messages, only: :create
    resources :surface_actions, only: :create
    resources :surfaces, only: :destroy, param: :surface_id
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end

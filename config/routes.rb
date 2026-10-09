Rails.application.routes.draw do
  resources :getty_assets, only: %i[index show create] do
    post :refetch, on: :member
  end
  root "getty_assets#index"
end

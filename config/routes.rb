Rails.application.routes.draw do
  devise_for :users

  resources :users, only: :show
  resources :admin, only: :index

  scope 'admin/users/:id', controller: 'admin' do
    put '/make_admin', action: 'make_admin', as: :make_admin
    put '/approve', action: 'approve', as: :approve
    put '/reject', action: 'reject', as: :reject
  end

  resources :projects do
    resources :comments, only: %i[show create update destroy]
    resource :likes, only: %i[create destroy]
  end

  resources :flags, only: %i[index create] do
    put 'resolve', action: 'resolve', on: :member, as: :resolve
    put 'reject', action: 'reject', on: :member, as: :reject
  end

  resources :bugs, only: %i[new create]

  root 'pages#home', as: :authenticated_root
end

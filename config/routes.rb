Rails.application.routes.draw do
  match '/oauth2callback',
    to: Google::Auth::WebUserAuthorizer::CallbackApp,
    via: :all
  
  resources :googles

  get 'admins/load' => 'admins#load', as: :loadgoogle
  get 'admins/load2' => 'admins#load2', as: :load2google
  get 'admins/load2c' => 'admins#load2c', as: :load2cgoogle

  post 'removetutorfromsession' => 'tutroles#removetutorfromsession', as: :removetutorfromsession
  post 'tutorcopysession' =>       'tutroles#tutorcopysession', as: :tutorcopysession
  post 'tutormovesession' =>       'tutroles#tutormovesession', as: :tutormovesession
  resources :tutroles

  post 'removestudentfromsession' => 'roles#removestudentfromsession', as: :removestudentfromsession
  post 'studentcopysession' => 'roles#studentcopysession', as: :studentcopysession
  post 'studentmovesession' => 'roles#studentmovesession', as: :studentmovesession
  resources :roles

  get 'calendar/display'
  get 'calendar/display2' => 'calendar#display2', as: :calendar_display2

  get 'sessions/:id/move' => 'sessions#move', as: :move_session
  post 'sessions/:id' => 'sessions#update', as: :update_session
  resources :sessions

  resources :slots

  resources :tutors

  get 'students/:id/showsessions' => 'students#showsessions', as: :show_sessions
  resources :students

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'
  root 'calendar#display'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end

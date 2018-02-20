Rails.application.routes.draw do
  match '/oauth2callback',
    to: Google::Auth::WebUserAuthorizer::CallbackApp,
    via: :all
  
  resources :googles

  get 'admins/load' => 'admins#load', as: :load
  get 'admins/loadtutors' => 'admins#loadtutors', as: :loadtutors
  get 'admins/loadstudents' => 'admins#loadstudents', as: :loadstudents
  get 'admins/loadschedule' => 'admins#loadschedule', as: :loadschedule
  get 'admins/loadtest' => 'admins#loadtest', as: :loadtest


  post 'removetutorfromlesson' => 'tutroles#removetutorfromlesson', as: :removetutorfromlesson
  post 'tutorcopylesson' =>       'tutroles#tutorcopylesson', as: :tutorcopylesson
  post 'tutormovelesson' =>       'tutroles#tutormovelesson', as: :tutormovelesson
  resources :tutroles

  post 'removestudentfromlesson' => 'roles#removestudentfromlesson', as: :removestudentfromlesson
  post 'studentcopylesson' => 'roles#studentcopylesson', as: :studentcopylesson
  post 'studentmovelesson' => 'roles#studentmovelesson', as: :studentmovelesson
  resources :roles

  get 'calendar/display'
  get 'calendar/display2' => 'calendar#display2', as: :calendar_display2

  get 'lessons/:id/move' => 'lessons#move', as: :move_lesson
  post 'lessons/:id' => 'lessons#update', as: :update_lesson
  resources :lessons

  resources :slots

  resources :tutors

  get 'students/:id/showlessons' => 'students#showlessons', as: :show_lessons
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

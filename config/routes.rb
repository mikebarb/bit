Rails.application.routes.draw do
  devise_for :users, controllers: {registrations: 'registrations' } 
  devise_scope :user do
    get 'users/preferences/' => 'registrations#edit_preferences',   as: :edit_user_preferences
    put 'users/preferences/' => 'registrations#update_preferences', as: :user_preferences

    get 'users/index_roles/' => 'registrations#index_roles',        as: :index_user_roles
    get 'users/roles/:id'       => 'registrations#edit_roles',         as: :edit_user_roles
    put 'users/roles/'       => 'registrations#update_roles',       as: :user_roles
  end
  
  match '/oauth2callback',
    to: Google::Auth::WebUserAuthorizer::CallbackApp,
    via: :all
  
  resources :googles

  get 'admins/home' => 'admins#home', as: :home
  get 'admins/load' => 'admins#load', as: :load
  get 'admins/loadtutors' => 'admins#loadtutors', as: :loadtutors
  get 'admins/loadstudents' => 'admins#loadstudents', as: :loadstudents
  get 'admins/loadschedule' => 'admins#loadschedule', as: :loadschedule
  get 'admins/loadtest' => 'admins#loadtest', as: :loadtest


  post 'removetutorfromlesson' => 'tutroles#removetutorfromlesson', as: :removetutorfromlesson
  post 'tutorcopylesson' =>       'tutroles#tutorcopylesson', as: :tutorcopylesson
  post 'tutormovelesson' =>       'tutroles#tutormovelesson', as: :tutormovelesson
  post 'tutorupdateskc' =>           'tutroles#tutorupdateskc', as: :tutorupdateskc
  resources :tutroles

  post 'removestudentfromlesson' => 'roles#removestudentfromlesson', as: :removestudentfromlesson
  post 'studentcopylesson' => 'roles#studentcopylesson', as: :studentcopylesson
  post 'studentmovelesson' => 'roles#studentmovelesson', as: :studentmovelesson
  post 'studentupdateskc' =>           'roles#studentupdateskc', as: :studentupdateskc
  resources :roles

  get 'calendar/display'
  get 'calendar/display2' => 'calendar#display2', as: :calendar_display2

  get 'lessons/:id/move' => 'lessons#move', as: :move_lesson
  post 'lessons/:id' => 'lessons#update', as: :update_lesson
  post 'lessonupdateskc' =>           'lessons#lessonupdateskc', as: :lessonupdateskc
  resources :lessons

  resources :slots

  get 'tutors/history/:id' => 'tutors#history', as: :tutor_history
  get 'tutors/history' => 'tutors#allhistory', as: :tutors_history
  resources :tutors

  get 'students/history/:id' => 'students#history', as: :student_history
  get 'students/history' => 'students#allhistory', as: :students_history
  #get 'students/:id/showlessons' => 'students#showlessons', as: :show_lessons
  resources :students

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'
  root 'admins#home'

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

Rails.application.routes.draw do
  resources :changes
  devise_for :users, controllers: {registrations: 'registrations' } 
  devise_scope :user do
    get 'users/preferences/' => 'registrations#edit_preferences',   as: :edit_user_preferences
    put 'users/preferences/' => 'registrations#update_preferences', as: :user_preferences

    get 'users/index_roles/' => 'registrations#index_roles',        as: :index_user_roles
    get 'users/roles/:id'    => 'registrations#edit_roles',         as: :edit_user_roles
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
  get 'admins/loadstudents2' => 'admins#loadstudents2', as: :loadstudents2
  get 'admins/loadschedule' => 'admins#loadschedule', as: :loadschedule
  get 'admins/loadtest' => 'admins#loadtest', as: :loadtest
  get 'admins/loadtest2' => 'admins#loadtest2', as: :loadtest2
  get 'admins/googleroster' => 'admins#googleroster', as: :googleroster
  get 'admins/copydaysedit' => 'admins#copydaysedit', as: :copydaysedit
  get 'admins/copydays' => 'admins#copydays', as: :copydays
  get 'admins/deletedaysedit' => 'admins#deletedaysedit', as: :deletedaysedit
  get 'admins/deletedays' => 'admins#deletedays', as: :deletedays


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

  #get 'calendar/display'
  #get 'calendar/display1' => 'calendar#display1', as: :calendar_display1
  #get 'calendar/display1f' => 'calendar#display1f', as: :calendar_display1f
  #get 'calendar/display2' => 'calendar#display2', as: :calendar_display2
  #get 'calendar/roster1' => 'calendar#roster1', as: :calendar_roster1
  #get 'calendar/roster1f' => 'calendar#roster1f', as: :calendar_roster1f
  #get 'calendar/roster2' => 'calendar#roster2', as: :calendar_roster2

  get 'calendar/displayoptions/' => 'calendar#displayoptions',   as: :displayoptions
  get 'calendar/flexibledisplay/' => 'calendar#flexibledisplay', as: :flexibledisplay

  get 'lessons/:id/move' => 'lessons#move', as: :move_lesson
  post 'lessons/:id' => 'lessons#update', as: :update_lesson
  post 'lessonupdateskc' =>           'lessons#lessonupdateskc', as: :lessonupdateskc
  resources :lessons

  resources :slots

  get 'tutors/history/:id' => 'tutors#history', as: :tutor_history
  get 'tutors/history' => 'tutors#allhistory', as: :tutors_history
  get 'tutors/change/:id' => 'tutors#change', as: :tutor_change
  post 'tutordetailupdateskc' => 'tutors#tutordetailupdateskc', as: :tutors_tutordetailupdateskc
  resources :tutors

  get 'students/history/:id' => 'students#history', as: :student_history
  get 'students/history' => 'students#allhistory', as: :students_history
  get 'students/change/:id' => 'students#change', as: :student_change
  post 'studentdetailupdateskc' => 'students#studentdetailupdateskc', as: :students_studentdetailupdateskc
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

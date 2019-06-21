require 'api_constraints'

Rails.application.routes.draw do
  # Api definition
  #namespace :api, defaults: { format: :json }, constraints: { subdomain: 'api' }, path: '/' do
  #  scope module: :v1,  constraints: ApiConstraints.new(version: 1, default: true) do
  namespace :api, defaults: {format: :json} do
    #namespace :v1 do
    scope module: :v1,  constraints: ApiConstraints.new(version: 1, default: true) do
      # We are going to list our resources here
      #resources :users, :only => [:show]
      resources :users,        :only => [:show, :index]
      resources :sessions,     :only => [:create]
      delete 'sessions'          => '/api/v1/sessions#destroy'
      
      resources :students, :only => [:show]
      get 'allstudents'          => '/api/v1/students#allstudents'
      get 'students/history/:id' => '/api/v1/students#history'
    end
    scope module: :v2,  constraints: ApiConstraints.new(version: 2, default: false) do
      # We are going to list our resources here
      #resources :users, :only => [:show]
      resources :users, :only => [:show, :index]
    end
  end
  
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

  get '/auth' => 'auth#issue_token_request'

  get 'admins/home' => 'admins#home', as: :home
  get 'admins/load' => 'admins#load', as: :load
  get 'admins/loadtutors' => 'admins#loadtutors', as: :loadtutors
  get 'admins/loadstudents' => 'admins#loadstudents', as: :loadstudents
  get 'admins/loadstudents2' => 'admins#loadstudents2', as: :loadstudents2
  get 'admins/loadstudentsUpdates' => 'admins#loadstudentsUpdates', as: :loadstudentsUpdates
  get 'admins/loadschedule' => 'admins#loadschedule', as: :loadschedule
  get 'admins/loadtest' => 'admins#loadtest', as: :loadtest
  get 'admins/loadtest2' => 'admins#loadtest2', as: :loadtest2
  get 'admins/googleroster' => 'admins#googleroster', as: :googleroster
  get 'admins/copydaysedit' => 'admins#copydaysedit', as: :copydaysedit
  get 'admins/copydays' => 'admins#copydays', as: :copydays
  get 'admins/copytermdaysedit' => 'admins#copytermdaysedit', as: :copytermdaysedit
  get 'admins/copytermdays' => 'admins#copytermdays', as: :copytermdays
  get 'admins/copytermweeksedit' => 'admins#copytermweeksedit', as: :copytermweeksedit
  get 'admins/copytermweeks' => 'admins#copytermweeks', as: :copytermweeks
  get 'admins/deletedaysedit' => 'admins#deletedaysedit', as: :deletedaysedit
  get 'admins/deletedays' => 'admins#deletedays', as: :deletedays
  get 'admins/deleteolddataedit' => 'admins#deleteolddataedit', as: :deleteolddataedit
  get 'admins/deleteolddata' => 'admins#deleteolddata', as: :deleteolddata

  post 'removetutorfromlesson' => 'tutroles#removetutorfromlesson', as: :removetutorfromlesson
  post 'tutorcopylesson'       => 'tutroles#tutorcopylesson',       as: :tutorcopylesson
  post 'tutormovelesson'       => 'tutroles#tutormovelesson',       as: :tutormovelesson
  post 'tutormovecopylesson'   => 'tutroles#tutormovecopylesson',   as: :tutormovecopylesson
  post 'tutorupdateskc'        => 'tutroles#tutorupdateskc',        as: :tutorupdateskc
  resources :tutroles

  post 'removestudentfromlesson' => 'roles#removestudentfromlesson', as: :removestudentfromlesson
  post 'studentcopylesson'       => 'roles#studentcopylesson',       as: :studentcopylesson
  post 'studentmovelesson'       => 'roles#studentmovelesson',       as: :studentmovelesson
  post 'studentmovecopylesson'   => 'roles#studentmovecopylesson',   as: :studentmovecopylesson
  post 'studentupdateskc'        => 'roles#studentupdateskc',        as: :studentupdateskc
  get  'catchups'                => 'roles#catchups',                as: :catchups
  get  'catchupoptions'          => 'roles#catchupoptions',          as: :catchupoptions
  post 'expirecatchups'          => 'roles#expirecatchups',          as: :expirecatchups
  resources :roles

  get 'calendar/displayoptions/'  => 'calendar#displayoptions',  as: :displayoptions
  get 'calendar/flexibledisplay/' => 'calendar#flexibledisplay', as: :flexibledisplay
  get 'calendar/globalstudents'   => 'calendar#globalstudents',  as: :globalstudents
  get 'calendar/pivotstats'       => 'calendar#pivotstats',      as: :pivotstats
  get 'calendar/pivotoptions'     => 'calendar#pivotoptions',    as: :pivotoptions

  get  'lessons/:id/move'       => 'lessons#move',                  as: :move_lesson
  post 'lessonmoveslot'         => 'lessons#lessonmoveslot',        as: :lessonmoveslot
  post 'lessonadd'              => 'lessons#lessonadd',             as: :lessonadd
  post 'lessonextend'           => 'lessons#lessonextend',          as: :lessonextend
  post 'lessontosinglechain'    => 'lessons#lessontosinglechain',   as: :lessontosinglechain
  delete 'lessonremove'         => 'lessons#lessonremove',          as: :lessonremove
  post 'lessons/:id'            => 'lessons#update',                as: :update_lesson
  post 'lessonupdateskc'        => 'lessons#lessonupdateskc',       as: :lessonupdateskc
  post 'lessonupdatestatusrun'  => 'lessons#lessonupdatestatusrun', as: :lessonupdatestatusrun
  resources :lessons

  resources :slots

  get 'tutors/history/:id' => 'tutors#history',         as: :tutor_history
  get 'tutors/chain/:id'   => 'tutors#chain',           as: :tutor_chain
  get 'tutors/term/:id'    => 'tutors#term',            as: :tutors_term
  get 'tutors/history'     => 'tutors#allhistory',      as: :tutors_history
  get 'tutors/change/:id'  => 'tutors#change',          as: :tutor_change
  get 'alltutors'          => 'tutors#alltutors',       as: :alltutors
  get 'allactivetutors'    => 'tutors#allactivetutors', as: :allactivetutors
  get 'activetutors'       => 'tutors#activetutors',    as: :activetutors
  post 'tutordetailupdateskc' => 'tutors#tutordetailupdateskc', as: :tutors_tutordetailupdateskc
  resources :tutors

  get 'students/history/:id'  => 'students#history',           as: :student_history
  get 'students/feedback/:id' => 'students#feedback',          as: :student_feedback
  get 'students/chain/:id'    => 'students#chain',             as: :student_chain
  get 'students/term/:id'     => 'students#term',              as: :students_term
  get 'students/history'      => 'students#allhistory',        as: :students_history
  get 'students/feedback'     => 'students#allfeedback',       as: :students_feedback
  get 'students/change/:id'   => 'students#change',            as: :student_change
  get 'allstudents'           => 'students#allstudents',       as: :allstudents
  get 'allactivestudents'     => 'students#allactivestudents', as: :allactivestudents
  get 'activestudents'        => 'students#activestudents',    as: :activestudents
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

class RegistrationsController < Devise::RegistrationsController


#  def account_update
#    # https://blog.metova.com/how-to-add-password-validation-to-your-devise-models/
#    byebug
#    if params[@devise_mapping.name][:password_confirmation].blank?
#        params[@devise_mapping.name].delete(:password)
#        params[@devise_mapping.name].delete(:password_confirmation)
#        #params[@devise_mapping.name].delete(:current_password)
#    end
#    byebug
#    super
#  end

  # GET /edit_preferences/1
  def edit_preferences
    if user_signed_in? 
      @user = User.find_by email: current_user.email
    end
  end

  # PATCH/PUT /update_preferences/1
  def update_preferences
    if user_signed_in? && current_user.email == update_preferences_params[:email]
      @user = User.find_by email: current_user.email
      
      updatetext = ""
      flagupdate = 0
      if @user.daystart != update_preferences_params[:daystart]
        @user.daystart = update_preferences_params[:daystart]
        flagupdate = 1
        updatetext = updatetext + " - daystart"  
      end
      if @user.daydur != update_preferences_params[:daydur]
        @user.daydur = update_preferences_params[:daydur]
        flagupdate = 1
        updatetext = updatetext + " - daydur"  
      end
      if @user.ssurl != update_preferences_params[:ssurl]
        @user.ssurl = update_preferences_params[:ssurl]
        flagupdate = 1
        updatetext = updatetext + " - ssurl"  
      end
      if @user.sstab != update_preferences_params[:sstab]
        @user.sstab = update_preferences_params[:sstab]
        flagupdate = 1
        updatetext = updatetext + " - sstab"  
      end
      if @user.history_back != update_preferences_params[:history_back]
        @user.history_back = update_preferences_params[:history_back]
        flagupdate = 1
        updatetext = updatetext + " - history_back"  
      end
      if @user.history_forward != update_preferences_params[:history_forward]
        @user.history_forward = update_preferences_params[:history_forward]
        flagupdate = 1
        updatetext = updatetext + " - history_forward"  
      end
      if @user.termstart != update_preferences_params[:termstart]
        @user.termstart = update_preferences_params[:termstart]
        flagupdate = 1
        updatetext = updatetext + " - termstart"  
      end
      if @user.termweeks != update_preferences_params[:termweeks]
        @user.termweeks = update_preferences_params[:termweeks]
        flagupdate = 1
        updatetext = updatetext + " - termweeks"  
      end
      if @user.rosterstart != update_preferences_params[:rosterstart]
        @user.rosterstart = update_preferences_params[:rosterstart]
        flagupdate = 1
        updatetext = updatetext + " - rosterstart"  
      end
      if @user.rosterdays != update_preferences_params[:rosterdays]
        @user.rosterdays = update_preferences_params[:rosterdays]
        flagupdate = 1
        updatetext = updatetext + " - rosterdays"  
      end
      if @user.rosterssurl != update_preferences_params[:rosterssurl]
        @user.rosterssurl = update_preferences_params[:rosterssurl]
        flagupdate = 1
        updatetext = updatetext + " - rosterssurl"  
      end
      logger.debug "flagupdate: " + flagupdate.inspect + " user_preferences: " + @user.inspect
      if flagupdate == 1                   # something changed - need to save
        if @user.save
          logger.debug "@user saved changes successfully"
          respond_to do |format|
            format.html { redirect_to home_url, notice: 'Updating preferences was successfull. Updated ' + updatetext }
          end
        else
          logger.debug "@user saving failed - " + @user.errors
          respond_to do |format|
            format.html { redirect_to user_preferences_path, notice: 'Updating preferences failed.' }
          end
        end
      else
          logger.debug "@user required no updates"
      end
    end
  end

  # GET /index_roles
  def index_roles
    if user_signed_in? && current_user.role == 'admin'
      @users = User.all
    else
      redirect_to home_url      
    end
  end

  # GET /edit_roles/1
  def edit_roles
    if user_signed_in? && current_user.role == 'admin'
      @user = User.find params[:id]
    else
      redirect_to home_url
    end
  end
  
  # PATCH/PUT /update_roles/1
  def update_roles
    if user_signed_in? && current_user.role == 'admin'
      @user = User.find_by email: update_roles_params[:email]
      
      updatetext = ""
      flagupdate = 0
      if @user.role != update_roles_params[:role]
        @user.role = update_roles_params[:role]
        flagupdate = 1
        updatetext = updatetext + " - role"  
      end
      logger.debug "flagupdate: " + flagupdate.inspect + " user_roles: " + @user.inspect
      if flagupdate == 1                   # something changed - need to save
        if @user.save
          logger.debug "this user had changes saved successfully"
          respond_to do |format|
            format.html { redirect_to home_url, notice: 'Updating roles was successfull. Updated ' + updatetext }
          end
        else
          logger.debug "@user saving failed - " + @user.errors
          respond_to do |format|
            format.html { redirect_to user_preferences_path, notice: 'Updating this user role failed.' }
          end
        end
      else
          logger.debug " this user role had no changes"
      end
    else
      redirect_to home_url
    end
  end


  # Never trust parameters from the scary internet, only allow the white list through.
  private

  def update_roles_params
    params.require(:user).permit(:email, :role)
  end

  def update_preferences_params
    params.require(:user).permit(:email, :daystart, :daydur, :ssurl, :sstab,
                                 :history_back, :history_forward,
                                 :termstart, :termweeks, :rosterstart, 
                                 :rosterdays, :rosterssurl)
  end

  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation,
                                 :role)
  end
  
  def account_update_params
    params.require(:user).permit(:email, :password, :password_confirmation, 
                                 :current_password, :role,
                                 :daystart, :daydur, :ssurl, :sstab)
  end

end
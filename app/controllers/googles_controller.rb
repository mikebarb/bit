class GooglesController < ApplicationController
  before_action :set_google, only: [:show, :edit, :update, :destroy]

  # GET /googles
  # GET /googles.json
  def index
    @googles = Google.all
  end

  # GET /googles/1
  # GET /googles/1.json
  def show
  end

  # GET /googles/new
  def new
    @google = Google.new
  end

  # GET /googles/1/edit
  def edit
  end

  # POST /googles
  # POST /googles.json
  def create
    @google = Google.new(google_params)

    respond_to do |format|
      if @google.save
        format.html { redirect_to @google, notice: 'Google was successfully created.' }
        format.json { render :show, status: :created, location: @google }
      else
        format.html { render :new }
        format.json { render json: @google.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /googles/1
  # PATCH/PUT /googles/1.json
  def update
    respond_to do |format|
      if @google.update(google_params)
        format.html { redirect_to @google, notice: 'Google was successfully updated.' }
        format.json { render :show, status: :ok, location: @google }
      else
        format.html { render :edit }
        format.json { render json: @google.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /googles/1
  # DELETE /googles/1.json
  def destroy
    @google.destroy
    respond_to do |format|
      format.html { redirect_to googles_url, notice: 'Google was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_google
      @google = Google.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def google_params
      params.require(:google).permit(:user, :client_id, :access_token, :refresh_token, :scope)
    end
end

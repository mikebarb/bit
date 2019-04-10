class SlotsController < ApplicationController
  before_action :set_slot, only: [:show, :edit, :update, :destroy]
  before_filter :authenticate_user!, :set_user_for_models
  after_filter :reset_user_for_models
  

  # GET /slots
  # GET /slots.json
  def index
    @slots = Slot
             .order(id: :desc)
             .page(params[:page])
  end

  # GET /slots/1
  # GET /slots/1.json
  def show
  end

  # GET /slots/new
  def new
    @slot = Slot.new
  end

  # GET /slots/1/edit
  def edit
  end

  # POST /slots
  # POST /slots.json
  def create
    @slot = Slot.new(slot_params)

    respond_to do |format|
      if @slot.save
        @slot.first = @slot.id
        @slot.save
        format.html { redirect_to @slot, notice: 'Slot was successfully created.' }
        format.json { render :show, status: :created, location: @slot }
      else
        format.html { render :new }
        format.json { render json: @slot.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /slots/1
  # PATCH/PUT /slots/1.json
  def update
    if @slot.first == nil
      @slot.first = @slot.id
    end
    respond_to do |format|
      if @slot.update(slot_params)
        format.html { redirect_to @slot, notice: 'Slot was successfully updated.' }
        format.json { render :show, status: :ok, location: @slot }
      else
        format.html { render :edit }
        format.json { render json: @slot.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /slots/1
  # DELETE /slots/1.json
  def destroy
    if @slot.destroy
      respond_to do |format|
        format.html { redirect_to slots_url, notice: 'Slot was successfully destroyed.' }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_to slots_url, notice: 'Slot was NOT destroyed.' }
        format.json { render json: @slot.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_slot
      @slot = Slot.find(params[:id])
    end

    def set_user_for_models
      Thread.current[:current_user_id] = current_user.id
    end
    
    def reset_user_for_models
      Thread.current[:current_user_id] = nil
    end
    
    # Never trust parameters from the scary internet, only allow the white list through.
    def slot_params
      params.require(:slot).permit(:timeslot, :location, :comment)
    end
end

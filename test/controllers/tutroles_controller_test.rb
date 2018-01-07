require 'test_helper'

class TutrolesControllerTest < ActionController::TestCase
  setup do
    @tutrole = tutroles(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:tutroles)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create tutrole" do
    assert_difference('Tutrole.count') do
      post :create, tutrole: { session_id: @tutrole.session_id, tutor_id: @tutrole.tutor_id }
    end

    assert_redirected_to tutrole_path(assigns(:tutrole))
  end

  test "should show tutrole" do
    get :show, id: @tutrole
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @tutrole
    assert_response :success
  end

  test "should update tutrole" do
    patch :update, id: @tutrole, tutrole: { session_id: @tutrole.session_id, tutor_id: @tutrole.tutor_id }
    assert_redirected_to tutrole_path(assigns(:tutrole))
  end

  test "should destroy tutrole" do
    assert_difference('Tutrole.count', -1) do
      delete :destroy, id: @tutrole
    end

    assert_redirected_to tutroles_path
  end
end

require 'test_helper'

class GooglesControllerTest < ActionController::TestCase
  setup do
    @google = googles(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:googles)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create google" do
    assert_difference('Google.count') do
      post :create, google: { access_token: @google.access_token, client_id: @google.client_id, refresh_token: @google.refresh_token, scope: @google.scope, user: @google.user }
    end

    assert_redirected_to google_path(assigns(:google))
  end

  test "should show google" do
    get :show, id: @google
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @google
    assert_response :success
  end

  test "should update google" do
    patch :update, id: @google, google: { access_token: @google.access_token, client_id: @google.client_id, refresh_token: @google.refresh_token, scope: @google.scope, user: @google.user }
    assert_redirected_to google_path(assigns(:google))
  end

  test "should destroy google" do
    assert_difference('Google.count', -1) do
      delete :destroy, id: @google
    end

    assert_redirected_to googles_path
  end
end

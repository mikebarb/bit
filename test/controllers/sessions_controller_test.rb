require 'test_helper'

class SessionsControllerTest < ActionController::TestCase
  setup do
    @student = students(:one)
    @tutor   = tutors(:one)
    @slot    = slots(:one)
    @session = sessions(:one)
    @session.student_id = @student.id
    @session.tutor_id   = @tutor.id
    @session.slot_id    = @slot.id
    @session.save

    @student = students(:two)
    @tutor   = tutors(:two)
    @slot    = slots(:two)
    @session = sessions(:two)
    @session.student_id = @student.id
    @session.tutor_id   = @tutor.id
    @session.slot_id    = @slot.id
    @session.save
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:sessions)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create session" do
    assert_difference('Session.count') do
      post :create, session: { comments: @session.comments, slot_id: @session.slot_id, student_id: @session.student_id, tutor_id: @session.tutor_id }
    end

    assert_redirected_to session_path(assigns(:session))
  end

  test "should show session" do
    get :show, id: @session
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @session
    assert_response :success
  end

  test "should update session" do
    patch :update, id: @session, session: { comments: @session.comments, slot_id: @session.slot_id, student_id: @session.student_id, tutor_id: @session.tutor_id }
    assert_redirected_to session_path(assigns(:session))
  end

  test "should destroy session" do
    assert_difference('Session.count', -1) do
      delete :destroy, id: @session
    end

    assert_redirected_to sessions_path
  end
end

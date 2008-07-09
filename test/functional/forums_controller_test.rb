require File.dirname(__FILE__) + '/../test_helper'
require 'forums_controller'

# Re-raise errors caught by the controller.
class ForumsController; def rescue_action(e) raise e end; end

class ForumsControllerTest < Test::Unit::TestCase
  fixtures :forums, :users

  def setup
    @controller = ForumsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    
    login_as 'allroles'
  end

  def test_index
    get :index

    assert_response :success
    assert_template 'index'

    assert_not_nil assigns(:forums)
  end

  def test_create
    num_forums = Forum.count

    post :create, :forum => { :name => "x" }

    assert_response :redirect
    assert_redirected_to :controller => 'forums', :action => 'index'

    assert_equal num_forums + 1, Forum.count
  end

  def test_edit
    get :edit, :id => forums(:bugs_forum)

    assert_response :success
    assert_template 'edit'

    assert_not_nil assigns(:forum)
    assert assigns(:forum).valid?
  end

  def test_update
    put :update, :id => forums(:bugs_forum)
    assert_response :redirect
    assert_redirected_to :controller => 'forums', :action => 'index'
  end

  def test_destroy
    assert_nothing_raised {
      Forum.find(forums(:bugs_forum).id)
    }

    delete :destroy, :id => forums(:bugs_forum).id
    assert_response :redirect
    assert_redirected_to forums_path

    assert_raise(ActiveRecord::RecordNotFound) {
      Forum.find(forums(:bugs_forum).id)
    }
  end
end
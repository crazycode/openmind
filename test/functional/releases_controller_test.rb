require File.dirname(__FILE__) + '/../test_helper'
require 'releases_controller'

# Re-raise errors caught by the controller.
class ReleasesController; def rescue_action(e) raise e end; end

class ReleasesControllerTest < Test::Unit::TestCase
  fixtures :releases, :users, :roles_users

  def setup
    @controller = ReleasesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @first_id = releases(:controller_test).id
    login_as 'allroles'
  end
  
  def test_routing  
    with_options :controller => 'releases' do |test|
      test.assert_routing 'releases', :action => 'index'
      test.assert_routing 'releases/1', :action => 'show', :id => '1'
      test.assert_routing 'releases/1/edit', :action => 'edit', :id => '1'
    end
    assert_recognizes({:controller => 'releases', :action => 'create'},
      :path => 'releases', :method => :post)
    assert_recognizes({:controller => 'releases', :action => 'update', :id => "1"},
      :path => 'releases/1', :method => :put)
    assert_recognizes({:controller => 'releases', :action => 'destroy', :id => "1"},
      :path => 'releases/1', :method => :delete)
  end

  def test_index_with_no_product
    get :index
    assert_response :redirect
    assert_redirected_to :action => :index, :controller => :products
  end

  def test_index
    get :index, :product_id => releases(:controller_test).product

    assert_response :success
    assert_template 'index'

    assert_not_nil assigns(:releases)
  end

  def test_show
    get :show, :id => @first_id

    assert_response :success
    assert_template 'show'

    assert_not_nil assigns(:release)
    assert assigns(:release).valid?
  end

  def test_create
    num_releases = Release.count

    post :create, :product_id => Product.find(:first).id, 
      :release => { :version => "1.999",       
      :release_status_id => LookupCode.find(:first).id
    }

    assert_response :redirect
    assert_redirected_to releases_path(:product_id => Product.find(:first).id)

    assert_equal num_releases + 1, Release.count
  end

  def test_edit
    get :edit, :id => @first_id

    assert_response :success
    assert_template 'edit'

    assert_not_nil assigns(:release)
    assert assigns(:release).valid?
  end

  def test_update
    put :update, :id => @first_id
    assert_response :redirect
    assert_redirected_to releases_path(:product_id => Release.find(@first_id).product.id)
  end

  def test_destroy
    product_id = nil
    assert_nothing_raised {
      product_id = Release.find(@first_id).product.id
    }

    delete :destroy, :id => @first_id
    assert_response :redirect
    assert_redirected_to releases_path(:product_id => product_id)

    assert_raise(ActiveRecord::RecordNotFound) {
      Release.find(@first_id)
    }
  end
end

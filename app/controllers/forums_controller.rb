class ForumsController < ApplicationController
  before_filter :login_required, :except => [:index, :show, :rss, :search, :tag]
  access_control [:new, :destroy ] => 'sysadmin',
    [:edit, :create, :update ] => 'sysadmin|mediator'
  helper :topics

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [:create ],
    :redirect_to => { :action => :index }
  verify :method => :put, :only => [ :update ],
    :redirect_to => { :action => :index }
  verify :method => :delete, :only => [ :destroy ],
    :redirect_to => { :action => :index }


  def new
    @forum = Forum.new
    @mediators = Role.find_users_by_role('mediator')
  end
  
  def show
    @forum = Forum.find(params[:id])
    @topics = Topic.list(params[:page],
      current_user == :false ? 10 : current_user.row_limit, 
      @forum,
      (@forum.mediators.include? current_user))
    unless @forum.can_see? current_user or prodmgr?
      flash[:error] = ForumsController.flash_for_forum_access_denied(current_user)
      redirect_to redirect_path_on_access_denied current_user
    end
  end
  
  def index
    #    @forums = Forum.list params[:page], (current_user == :false ? 10 : current_user.row_limit)
    @forums = Forum.list_by_forum_group.find_all{|forum| forum.can_see? current_user}
    @forum_groups = ForumGroup.list_all current_user
  end

  def create
    params[:forum][:mediator_ids] ||= []
    params[:forum][:group_ids] ||= []
    params[:forum][:enterprise_type_ids] ||= []
    @forum = Forum.new(params[:forum])
    if @forum.save
      flash[:notice] = "Forum #{@forum.name} was successfully created."
      redirect_to forums_path
    else
      @mediators = Role.find_users_by_role('mediator')
      render :action => :new
    end
  end

  def edit
    @forum = Forum.find(params[:id])
    @mediators = Role.find_users_by_role('mediator')
    unless @forum.can_edit? current_user
      flash[:error] = "You do not have access to edit that forum"
      redirect_to forums_path
    end
  end

  def update
    params[:forum][:mediator_ids] ||= []
    params[:forum][:group_ids] ||= []
    params[:forum][:enterprise_type_ids] ||= []
    @forum = Forum.find(params[:id])
    unless @forum.can_edit? current_user
      flash[:error] = "You do not have access to edit that forum"
      redirect_to forums_path
    end
    if @forum.update_attributes(params[:forum])
      flash[:notice] = "Forum '#{@forum.name}' was successfully updated."
      redirect_to forum_path(@forum)
    else
      render :action => :edit
    end
  end
  
  def search
    @hits = {}
    session[:forums_search] = params[:search]
    Topic.find_by_solr(params[:search], :scores => true).docs.each do |topic|
      @hits[topic.id] = TopicHit.new(topic, true, topic.solr_score) if topic.forum.can_see?(current_user) or prodmgr?
    end
    TopicComment.find_by_solr(params[:search], :scores => true).docs.each do |comment|
      if (comment.topic.forum.can_see?(current_user) or prodmgr?) and
          (!comment.private or comment.topic.forum.mediators.include? current_user)
        # first see if topic hit already exists
        topic_hit = @hits[comment.topic.id]
        if topic_hit.nil?
          hit = TopicHit.new(comment.topic, false, comment.solr_score)
          hit.comments << comment   
          @hits[comment.topic.id] = hit
        else
          topic_hit.comments << comment
          topic_hit.score = comment.solr_score if topic_hit.score < comment.solr_score
        end	
      end
    end
    TopicHit.normalize_scores(@hits.values)
  end

  def destroy
    forum = Forum.find(params[:id])
    name = forum.name
    forum.destroy
    flash[:notice] = "Forum #{name} was successfully deleted."
    redirect_to forums_url
  end
  
  def toggle_forum_details_box
    @forum = Forum.find(params[:id])
    if session[:forum_details_box_display] == "SHOW"
      session[:forum_details_box_display] = "HIDE"
    else
      session[:forum_details_box_display] = "SHOW"
    end
    
    respond_to do |format|
      format.html { 
        index
      }
      format.js  { do_rjs_toggle_forum_details_box }
    end
  end

  # Build an rss feed to be notified of new forum postings
  def rss
    forum = Forum.find(params[:id])
    comments = forum.comments_by_topic.find_all{|c| !c.private and forum.can_see? current_user}
    render_rss_feed_for comments, {
      :feed => {
        :title => "New OpenMind Comments for Forum \"#{forum.name}\"",
        :link => forum_url(forum.id),
        :pub_date => :created_at
      },
      :item => {
        :title => :rss_headline,
        :description => :rss_body,
        :link => Proc.new{|comment| "#{topic_url(comment.topic.id, :anchor => comment.id)}" }
      }
    }
  end
  
  def self.flash_for_forum_access_denied user
    return "You must be logged on to access this forum" if user == :false
    return "You have insuffient permissions to access this forum" unless user == :false    
  end

  def tag
    @hits = {}
    @tags = params[:id]
    @forum = Forum.find(params[:forum]) unless params[:forum].nil?
    Topic.find_tagged_with(@tags).each do |topic|
      if (topic.forum.can_see?(current_user) or prodmgr?) and
          (@forum.nil? or @forum.id == topic.forum.id)
        @hits[topic.id] = TopicHit.new(topic, true, 100)
      end
    end
    render :action => :search
  end
  
  private
  
  def redirect_path_on_access_denied user
    return forums_path unless user == :false
    return url_for :controller => 'account', :action => 'login', :only_path => true if user == :false
  end
  
  def do_rjs_toggle_forum_details_box 
    render :update do |page|
      page.replace "forum_details_area", 
        :partial => "show_hide_forum_details"
      if session[:forum_details_box_display] == "HIDE"
        page.visual_effect :blind_up, :forum_details, :duration => 0.5
      else
        page.visual_effect :blind_down, :forum_details, :duration => 1
      end
    end
  end
end
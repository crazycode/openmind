class AttachmentsController < ApplicationController
  include ActionView::Helpers::NumberHelper
  before_filter :login_required, :except => [ :download, :html ]
  access_control [:index, :edit, :update] => 'prodmgr | sysadmin | mediator',
    [:destroy] => 'prodmgr | sysadmin'
  cache_sweeper :attachments_sweeper, :only => [ :create, :update, :destroy, :search ]

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [:create ],
    :redirect_to => { :action => :index }
  verify :method => :put, :only => [ :update ],
    :redirect_to => { :action => :index }
  verify :method => :delete, :only => [ :destroy ],
    :redirect_to => { :action => :index }

  def index
    session[:attachments_search] = nil
    @attachment ||= Attachment.new(:public => true)
    unless read_fragment({:controller => "attachments",
          :action => "list_attachments",
          :user_id => current_user.id,
          :page => (params[:page] || 1),
          :action_type => params["action"]})
      @attachments = Attachment.list params[:page], current_user.row_limit
    end
  end

  def search
    session[:attachments_search] = params[:search]

    params[:search] = StringUtils.sanitize_search_terms params[:search]
    begin
      search_results = Attachment.find_by_solr(params[:search], :lazy => true).docs.collect(&:id)
    rescue RuntimeError => e
      flash[:error] = "An error occurred while executing your search. Perhaps there is a problem with the syntax of your search string."
      logger.error(e)
      redirect_to attachments_path
    else
      @attachments = Attachment.list params[:page], 999, search_results
      render :action => 'index'
    end
  end

  def edit
    @attachment = Attachment.find(params[:id])
    unless @attachment.parent.nil?
      flash[:error] = "Cannot edit thumbnail information"
      redirect_to attachments_path
    end
  end

  def update
    params[:attachment][:enterprise_type_ids] ||= []
    params[:attachment][:group_ids] ||= []
    @attachment = Attachment.find(params[:id])
    Attachment.transaction do
      unless params[:attachment][:alias].blank?
        other_attachment = Attachment.find_by_alias(params[:attachment][:alias])
        unless other_attachment.nil? or
            other_attachment.id == @attachment.id
          if params[:attachment][:alias] == params[:attachment][:confirm_alias]
            # user has confirmed the change
            other_attachment.alias = nil
            other_attachment.save!
          else
            @attachment.attributes = params[:attachment]
            @attachment.confirm_alias = @attachment.alias
            flash[:error] =
              "An attachment with this alias already exists. Please confirm that you would like to move the alias to this attachment."
            render :action => :edit
            return
          end
        end
      end
    
      if @attachment.update_attributes(params[:attachment])
        unless from_comment? params
          @attachment.public = (params[:attachment][:public] == "true")
          @attachment.alias = nil if @attachment.alias.blank?
          @attachment.enterprise_types.clear if @attachment.public and !@attachment.enterprise_types.empty?
          @attachment.groups.clear if @attachment.public and !@attachment.groups.empty?
          @attachment.save!
        end
        flash[:notice] = "Attachment '#{@attachment.filename}' was successfully updated."
        redirect_to attachment_path(@attachment)
      else
        render :action => :edit
        # roll back in case alias on another record w/ alias was updated
        raise ActiveRecord::Rollback
      end
    end
  end

  def toggle_etypes
    respond_to do |format|
      format.html {
      }
      format.js  { do_rjs_toggle_etypes(params['selected'] == 'true')}
    end
  end
  
  #  def new
  # # 	@attachment = Attachment.new # end

  def show
    @attachment = Attachment.find(params[:id])
  end

  def destroy
    attachment = Attachment.find(params[:id])
    name = attachment.filename
    attachment.destroy
    flash[:notice] = "Attachment #{name} was successfully deleted."
    redirect_to attachments_url
  end

  def html
    attachment = fetch_attachment(params[:id])
    if attachment.nil?
      @html = "Access denied"
    elsif attachment.content_type != 'text/html'
      flash[:error] = "This attachment is not a valid html file"
      @html = "Not valid HTML"
    else
      @html = attachment.data
    end
  end

  def download
    @attachment = fetch_attachment(params[:id])
    unless @attachment.nil?
      send_data @attachment.data, :filename => @attachment.filename
    end
  end

  def create
    if params[:attachment][:file].blank?
      redirect_on_error params, "Please specify a file to upload"
      return
    end
    if params[:attachment][:description].blank?
      redirect_on_error params, "Please specify a file description"
      return
    end
    if not_from_comment? params
      @attachment = Attachment.new(params[:attachment])
    else
      @attachment = CommentAttachment.new(params[:attachment])
      comment = Comment.find params[:comment_id]
      @attachment.comment = comment
    end
    @attachment.user = current_user

    if from_comment? params
      unless @attachment.image?
        redirect_on_error params, "Uploads are restricted to image files only"
        return
      end
      if @attachment.size > APP_CONFIG['max_file_upload_size'].to_i * 1024
        redirect_on_error params,
          "Upload exceeds maximum file size of #{number_to_human_size(APP_CONFIG['max_file_upload_size'].to_i * 1024)}"
        return
      end
    else
      @attachment.public = (params[:attachment][:public] == "true")
    end
    @attachment.alias = nil if @attachment.alias.blank?
    Attachment.transaction do
      if @attachment.save
        flash[:notice] = "Your file has been uploaded successfully"
        if @attachment.class.to_s == 'Attachment'
          redirect_to attachment_path(@attachment)
        else
          redirect_to calc_return_path(@attachment.comment)
        end
      else
        redirect_on_error params, "There was a problem submitting your attachment"
      end
    end
  end
  
  private
  
  def redirect_on_error params, err_msg
    flash[:error] =  err_msg
    if not_from_comment? params
      index
      render :action => :index
    else
      redirect_to attach_comment_path(Comment.find(params[:comment_id]))
    end
  end
  
  def calc_return_path comment
    if comment.class.to_s == 'TopicComment'
      topic_path(comment.topic.id, :anchor => comment.id.to_s)
    else
      url_for(:controller => 'ideas', :action => 'show', :id => comment.idea,
        :selected_tab => "COMMENTS", :anchor => comment.id.to_s)
    end
  end
  
  def from_comment? params
    !not_from_comment? params
  end
  
  def not_from_comment? params
    params[:comment_id].nil? or params[:comment_id].blank?
  end

  def do_rjs_toggle_etypes show_etypes
    attachment = Attachment.find(params[:id])
    render :update do |page|
      page.replace_html "buttons",  :partial => "buttons", :object => attachment
      #      page.replace "details",  :partial => "details", :object => attachment
      if show_etypes
        page.hide 'etypes'
        #        page.visual_effect :blind_up, :etypes, :duration => 0.5
      else
        page.show 'etypes'
        #        page.visual_effect :blind_down, :etypes, :duration => 1
      end
    end
  end

  def fetch_attachment id
    attachment = Attachment.find_by_alias(id)
    attachment = Attachment.find(id) if attachment.nil?
    if !attachment.public and !logged_in?
      flash[:error] = 'You must log on to see this file'
      redirect_to :controller => 'account', :action => 'login'
      return
    elsif !attachment.can_see? current_user
      flash[:error] = 'You do not have permission to access this file'
      redirect_to :controller => 'ideas'
      return
    else
      attachment.downloads += 1
      attachment.save!
      return attachment
    end
  end
end
module ForumsHelper
  def can_edit? forum
    sysadmin? or forum.can_edit? current_user unless current_user == :false
  end  
    
  def last_forum_post forum
    last_comment = forum.comments.public.most_recent.first unless forum.mediators.include? current_user
    last_comment = forum.comments.most_recent.first if forum.mediators.include? current_user
    return '-' if last_comment.nil?
    subject = ""
    subject += "RE: " if forum.comments.size > 1
    subject += link_to(last_comment.topic.title, 
      topic_path(last_comment.topic, :anchor => last_comment.id),
      html_options = {:onmouseover => "Tip('Jump to this post')"})
    subject = boldify(subject) if last_comment.topic.unread_comment?(current_user)
    
    comment = last_comment.body
    comment = boldify(comment) if last_comment.topic.unread_comment?(current_user)
    
    author = user_display_name last_comment.user
    author = boldify(author) if last_comment.topic.unread_comment?(current_user)
    "#{subject}<br/>#{author} wrote \"#{truncate StringUtils.strip_html(comment), 
    :length => 40}\"<br/>#{om_date_time last_comment.created_at}"
  end

  def dummy_all_forum
    forum = Forum.new(:name => "All Forums")
    forum.mediators = User.mediators
    forum
  end

  def dummy_unassigned_mediator
    user = User.new(:last_name => "Un-owned")
    user
  end

  def mediator_owner_filter_list
    names = []
    names << ["All", -1]
    names << ["Un-owned", 0]
    for user in @forum.mediators
      name = user_display_name(user)
      name = "#{user_display_name(user)} (inactive)" if !user.active
      names << [name, user.id]
    end
    names.sort!{|x,y| x[0].upcase <=> y[0].upcase }
    names
  end
    
  def last_topic_post topic
    return if topic.last_comment.nil?
    comment = topic.last_comment.body
    comment = boldify(comment) if topic.unread_comment?(current_user)
    
    author = user_display_name topic.last_comment.user
    author = boldify(author) if topic.unread_comment?(current_user)
    "#{author} wrote \"#{link_to truncate(StringUtils.strip_html(comment), :length => 40),
    topic_path(topic.id, :anchor => topic.last_comment.id)}\"<br/>#{om_date_time topic.last_comment.created_at}"
  end
  

  def show_topic_watch_icon topic
    if current_user == :false
      link_to theme_image_tag("icons/24x24/watchAdd.png", 
        :alt=>"Add watch", :title=> "add watch",
        :onmouseover => "Tip('Watch this topic (requires login)')"), 
        :url =>  create_topic_watch_watch_path(:id => topic),
        :html => { }, 
        :method => :post
    elsif topic.watchers.include? current_user
      link_to_remote theme_image_tag("icons/24x24/watchRemove.png", 
        :alt=>"Remove watch", :title=> "remove watch",
        :onmouseover => "Tip('Stop watching this topic')"), 
        :url =>  destroy_topic_watch_watch_path(:id => topic), 
        :html => {  }, 
        :method => :delete
    else
      link_to_remote theme_image_tag("icons/24x24/watchAdd.png", 
        :alt=>"Add watch", :title=> "add watch",
        :onmouseover => "Tip('Watch this topic')"), 
        :url =>  create_topic_watch_watch_path(:id => topic),
        :html => {  }, 
        :method => :post
    end
  end

  def types
    [
      ["Forum (Any user can create new topics and add comments to existing topics)",  "forum"],
      ["Blog (Only moderators can create new topics, all users can add comments to existing topics)",  "blog"],
      ["Announcement (Only moderators can create new topics and add comments to existing topics)",  "announcement"]
    ]
  end
  

  def show_forum_watch_icon forum
    if current_user == :false
      link_to theme_image_tag("icons/24x24/watchAdd.png", 
        :alt=>"Watch this forum and all topics within this forum (requires login)", :title=> "Watch this forum and all topics within this forum (requires login)",
        :onmouseover => "Tip('Watch this forum and all topics within this forum (requires login)')"), 
        create_forum_watch_watch_path(:id => forum),
        :html => {  }, 
        :method => :post
    elsif forum.watchers.include? current_user
      link_to_remote theme_image_tag("icons/24x24/watchRemove.png", 
        :alt=>"Don't automatically watch new topics in this forum", :title=> "Don't automatically watch new topics in this forum",
        :onmouseover => "Tip('Don't automatically watch new topics in this forum')"), 
        :url =>  destroy_forum_watch_watch_path(:id => forum), 
        :html => {  }, 
        :method => :delete
    else
      link_to_remote theme_image_tag("icons/24x24/watchAdd.png", 
        :alt=>"Watch this forum and all topics within this forum", :title=> "Watch this forum and all topics within this forum",
        :onmouseover => "Tip('Watch this forum and all topics within this forum')"), 
        :url =>  create_forum_watch_watch_path(:id => forum),
        :html => {  }, 
        :method => :post
    end
  end


  def show_forum_watch_button forum
    unless current_user == :false
      if forum.watchers.include? current_user
        link_to "Remove Forum Watch", 
          destroy_forum_watch_watch_path(:id => forum), 
          { :class => "button",
          :onmouseover => "Tip('Don't automatically watch new topics in this forum')",
          :method => :delete                }
      else
        link_to "Add Forum Watch", 
          create_forum_watch_watch_path(forum), 
          { :class => "button",
          :onmouseover => "Tip('Watch this forum and all topics within this forum')",
          :method => :post                   }
      end
    end
  end
  
  def expand_contract_forum_box_image
    image = "show.png"
    help = "Show forum details"
    if session[:forum_details_box_display] == "SHOW"
      image = "hide.png" 
      help = "Hide forum details"
    end
    theme_image_tag("icons/16x16/#{image}", :alt=> help, :title=> help,:onmouseover => "Tip('#{help}')")
  end
  
  def forum_details_box_display_style
    return "display:block;" if session[:forum_details_box_display] == "SHOW"
    return "display:none;"
  end

  def get_tags forum
    if forum.nil?
      # Restrict tags for forums that the user has access to
      Topic.tag_counts(:limit => 100, :conditions => ["topics.id in (?)",
          Forum.find(:all).find_all{|f| f.can_see? current_user}.collect(&:topics).flatten.collect(&:id)])
    else
      forum.topics.tag_counts(:limit => 100)
    end
  end
  
  private
  
  def boldify(text)
    "<b>#{text}</b>"
  end
end
# To change this template, choose Tools | Templates
# and open the template in the editor.

class ForumsSweeper < ActionController::Caching::Sweeper
  observe Forum # This sweeper is going to keep an eye on the Forum model

  # If our sweeper detects that a forum was created call this
  def after_save(forum)
    expire_cache_for(forum)
  end

  # If our sweeper detects that a forum was deleted call this
  def after_destroy(forum)
    expire_cache_for(forum)
  end

  private
  def expire_cache_for(record)
    # Expire a fragment
    expire_fragment(%r{forums.user_id=*})
    expire_fragment(%r{forums/most_active.forum=-1&user_id=*})
#    expire_fragment(:controller => 'forums', :action => 'index',
#      :page => params[:page] || 1)
  end
end
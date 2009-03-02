# To change this template, choose Tools | Templates
# and open the template in the editor.

class TopicsSweeper < ActionController::Caching::Sweeper
  observe Topic # This sweeper is going to keep an eye on the Topic model

  # If our sweeper detects that a topic was created call this
  def after_save(topic)
    expire_cache_for(topic)
  end

  # If our sweeper detects that a topic was deleted call this
  def after_destroy(topic)
    expire_cache_for(topic)
  end

  private
  def expire_cache_for(record)
    # Expire a fragment
    expire_fragment(%r{forums.user_id=*})
    expire_fragment(%r{forums/most_active.user_id=*})
#    expire_fragment(:controller => 'topics', :action => 'index',
#      :page => params[:page] || 1)
  end
end
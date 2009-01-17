# Class representing a search hit when performing a full text search on topics
class TopicHit
  attr_reader 	:topic , 		# The topic that was found
  :comments,		# List of matching comments
  :topic_hit		# True iff the topic was the hit
  # otherwise false if only a comment for the topic was a hit

  # how relevant the search score was
  attr_accessor  :score        
  
  def initialize(topic, topic_hit, score)
    @comments = []
    @topic_hit = topic_hit
    @topic = topic
    @score = score
  end
end
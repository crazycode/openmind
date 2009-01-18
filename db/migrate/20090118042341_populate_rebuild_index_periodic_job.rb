class PopulateRebuildIndexPeriodicJob < ActiveRecord::Migration
  def self.up
    # Regenerate SOLR indexes
    RunAtPeriodicJob.create(:job => 'Topic.rebuild_solr_index; TopicComment.rebuild_solr_index', :run_at_minutes => 210) # run at 3:30AM
  end

  def self.down
    RunIntervalPeriodicJob.find_by_job("Topic.rebuild_solr_index; TopicComment.rebuild_solr_index").destroy
  end
end

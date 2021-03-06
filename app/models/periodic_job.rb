# == Schema Information
# Schema version: 20081021172636
#
# Table name: periodic_jobs
#
#  id              :integer(4)      not null, primary key
#  type            :string(255)
#  job             :text
#  interval        :integer(4)
#  last_run_at     :datetime
#  run_at_minutes  :integer(4)
#  last_run_result :string(500)
#  next_run_at     :datetime
#  run_counter     :integer(4)
#

class PeriodicJob < ActiveRecord::Base
  before_create :set_initial_next_run
  
  def self.list(page, per_page)
    paginate :page => page, 
      :order => 'next_run_at DESC, last_run_at DESC',
      :per_page => per_page
  end
  
  def self.find_jobs_to_run
    # first grab all rows that are ready to run...we do this (with a lock)
    # to ensure that other threads or task_schedulers won't try to run 
    # the same jobs
    run_counter = TaskSchedulerBatch.get_next_count
    jobs = []
    PeriodicJob.transaction do
      jobs = PeriodicJob.find(:all, 
        :conditions => ['next_run_at < ? and run_counter is null', 
          Time.zone.now.to_s(:db)], 
        :order => "next_run_at ASC",
        # only grab one in case another task # only grab one in case another task 
        # server is running -- to load balance
        :limit => 1, 
        :lock => true) 
      for job in jobs
        job.update_attributes(:run_counter => run_counter, :last_run_result => 'Running')
      end
    end
    # okay, transaction should be committed (and lock freed at this point)
    # ...and this instance has grabbed the jobs it wants so no one else can
    jobs
  end
  
  # Execute jobs pending to run. Return true iff jobs were found to run
  def self.run_jobs
    TaskServerLogger.instance.debug("Checking for periodic jobs to run...")
    jobs = PeriodicJob.find_jobs_to_run
    jobs.each do |job|
      job.run!
    end
    !jobs.empty?
  end
  
  def calc_next_run
    nil
  end
  
  def can_delete?
    false  
  end
  
  def set_initial_next_run
    begin
      self.next_run_at = Time.zone.now if self.next_run_at.nil?
    rescue NoMethodError
      # Won't work if run during migration -  - column is added later, so swallow it
      raise unless ActiveRecord::Migrator.current_version.to_i < 68
    end
  end
  
  # Runs a job and updates the +last_run_at+ field.
  def run!
    TaskServerLogger.instance.info "Executing job id #{self.id}, #{self.to_s}..."
    begin
      eval(self.job)
      self.last_run_result = "OK"
      TaskServerLogger.instance.info "Job completed successfully"
    rescue Exception
      err_string = "'#{self.job}' could not run: #{$!.message}\n#{$!.backtrace}" 
      TaskServerLogger.instance.error err_string
      puts err_string 
      self.last_run_result = err_string.slice(1..500)
    end
    self.last_run_at = Time.zone.now
    self.next_run_at = nil
    self.save  
    
    # ...and persist the next run of this job if one exists
    next_job = self.calc_next_run
    next_job.save unless next_job.nil?
  end

  # Cleans up all jobs older than a day.
  def self.cleanup
    self.destroy_all ['last_run_at < ?', 7.day.ago]
  end
  
  def to_s
    "#{self.class.to_s}: #{job}"
  end
end

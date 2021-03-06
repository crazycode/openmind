# == Schema Information
# Schema version: 20081021172636
#
# Table name: roles
#
#  id           :integer(4)      not null, primary key
#  title        :string(50)      not null
#  description  :string(50)      not null
#  default_role :boolean(1)
#  lock_version :integer(4)      default(0)
#  created_at   :datetime        not null
#  updated_at   :datetime
#

class Role < ActiveRecord::Base
  validates_presence_of :title, :description
  validates_uniqueness_of :title
  validates_uniqueness_of :description
  validates_length_of :title, :maximum => 50
  validates_length_of :description, :maximum => 50
  
  has_and_belongs_to_many :users 
  
  #  def self.list(page)
  #    paginate :page => page, :order => 'description',
  #      :per_page => 10
  #  end
  
  def self.list
    Role.find(:all, :order => "description ASC" )
  end

  def can_delete?
    return false
  end  
  
  def self.find_default_roles
    Role.find_all_by_default_role(1)
  end
  
  def self.find_users_by_role(role_title)
    if @role_title.nil? or role_title != @role_title
      @role_title = role_title
      @role = Role.find_by_title(role_title)
    end
    users = []
    for user in User.find(:all, :order => 'email ASC')
      users << user if user.roles.include? @role
    end
    users    
  end
end

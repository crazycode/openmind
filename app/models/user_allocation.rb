# == Schema Information
# Schema version: 20081008013631
#
# Table name: allocations
#
#  id              :integer(4)      not null, primary key
#  quantity        :integer(4)      default(0), not null
#  comments        :text
#  user_id         :integer(4)
#  enterprise_id   :integer(4)
#  created_at      :datetime        not null
#  updated_at      :datetime        not null
#  lock_version    :integer(4)      default(0)
#  allocation_type :string(30)      not null
#  expiration_date :date            default(Tue, 20 Jan 2009), not null
#

class UserAllocation < Allocation
  validates_presence_of :user_id
  
  belongs_to :user
  
  def to_s
    "User Allocation, user: #{user.email}, quantity: #{quantity}"
  end
end

class CreateWatches < ActiveRecord::Migration
  def self.up
    create_table :watches, :id => false  do |t|
      t.column :user_id,  :integer, :null => false
      t.column :idea_id,  :integer, :null => false
      t.column :lock_version, :integer, :default => 0
      t.column :created_at, :datetime, :null => false
    end
    
    add_index :watches, [:user_id, :idea_id], :unique => true
  end

  def self.down
    drop_table :watches
  end
end

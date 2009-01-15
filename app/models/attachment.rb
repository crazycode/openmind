#   t.column :filename, :string, :limit => 50, :null => false
#   t.column :description, :string, :limit => 200, :null => false
#   t.column :content_type, :string, :limit => 20, :null => false
#   t.column :size, :integer, :null => false
#   t.column :data, :binary, :null => false
require 'fileutils'
require 'RMagick'

class Attachment < ActiveRecord::Base
  include Magick
  after_create :create_thumbnail
  
  validates_presence_of :filename, :description, :content_type, :size
  belongs_to :user
  has_one :thumbnail, :class_name => 'Attachment', 
    :foreign_key => :parent_attachment_id, :dependent => :delete
  # the attachment record for which this record is a thumbnail. If null, then
  # this image is not a thumbnail
  belongs_to :parent, :class_name => 'Attachment', :foreign_key => :parent_attachment_id

  def file=(incoming_file)
    self.filename = incoming_file.original_filename
    self.content_type = incoming_file.content_type
    self.size = incoming_file.size
    self.data = incoming_file.read
  end

  def filename=(new_filename)
    write_attribute("filename", sanitize_filename(new_filename))
  end

  def can_delete? user
    user.prodmgr? or user.sysadmin? or self.user == user
  end

  def self.list(page, per_page)
    paginate :page => page, 
      :conditions => 'parent_attachment_id IS NULL',
      :order => 'id DESC',
      :per_page => per_page
  end

  @@content_types = [
    'image/gif',
    'image/jpeg',
    'image/pjpeg',
    'image/bmp',
    'image/png',
    'image/x-png',
    'image/tiff'
  ]

  def image?
    content_type = self.content_type.downcase
    for ctype in @@content_types
      return true if ctype == content_type
    end
    logger.error "================= content type for update: #{content_type}"
    false
  end

  private
  def sanitize_filename(filename)
    return if filename.nil?
    # #get only the filename, not the whole path (from IE)
    just_filename = File.basename(filename)
    # #replace all non-alphanumeric, underscore or periods with underscores
    just_filename.gsub(/[^\w\.\-]/, '_')
  end

  def create_thumbnail
    # if a thumbnail, do nothing...avoid infinite recursion
    return unless parent.nil?
    
    thumbnail_data = gen_thumbnail_image(64, 64)
    unless thumbnail_data.nil?
      thumbnail_image = Attachment.new(:user => self.user, 
        :filename => "thumbnail-#{self.filename}",
        :description => "Thumbnail: #{self.description}",
        :data => thumbnail_data,
        :parent => self,
        :content_type => self.content_type,
        :size => thumbnail_data.size)
      thumbnail_image.save!
    end
  end

  def gen_thumbnail_image width=100, height=100
    if self.image?
      img = Magick::Image.from_blob(self.data).first
      rows, cols = img.rows, img.columns
      
      # thumbnail is larger than image...return image
      return self.data if rows < height and cols < width

      source_aspect = cols.to_f / rows
      target_aspect = width.to_f / height
      thumbnail_wider = target_aspect > source_aspect

      factor = thumbnail_wider ? width.to_f / cols : height.to_f / rows
      img.thumbnail!(factor)
      img.crop!(CenterGravity, width, height)
      img.to_blob
    end
  end
end

class BlogPost < ApplicationRecord
  belongs_to :user
  has_many_attached :images
  
  validates :title, presence: true, length: { minimum: 5, maximum: 100 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :content, presence: true, length: { minimum: 100 }
  validates :excerpt, presence: true, length: { minimum: 50, maximum: 300 }
  validates :meta_title, length: { maximum: 60 }
  validates :meta_description, length: { maximum: 160 }
  
  before_validation :generate_slug, if: -> { slug.blank? && title.present? }
  before_validation :generate_excerpt, if: -> { excerpt.blank? && content.present? }
  before_validation :generate_meta_fields, if: -> { title.present? }
  
  scope :published, -> { where(published: true).where.not(published_at: nil) }
  scope :featured, -> { where(featured: true) }
  scope :recent, -> { order(published_at: :desc) }
  scope :by_date, -> { order(published_at: :desc) }
  
  def to_param
    slug
  end
  
  def published?
    published && published_at.present? && published_at <= Time.current
  end
  
  def featured?
    featured
  end
  
  def publish!
    update!(published: true, published_at: Time.current)
  end
  
  def unpublish!
    update!(published: false, published_at: nil)
  end
  
  def toggle_featured!
    update!(featured: !featured)
  end
  
  def reading_time
    word_count = content.split.size
    (word_count / 200.0).ceil # Assuming 200 words per minute
  end
  
  def seo_title
    meta_title.presence || title
  end
  
  def seo_description
    meta_description.presence || excerpt
  end
  
  def display_date
    published_at.presence || created_at
  end
  
  def display_date_formatted(format = "%b %d, %Y")
    display_date.strftime(format)
  end
  
  private
  
  def generate_slug
    base_slug = title.parameterize
    self.slug = base_slug
    
    # Ensure uniqueness
    counter = 1
    while BlogPost.exists?(slug: slug)
      self.slug = "#{base_slug}-#{counter}"
      counter += 1
    end
  end
  
  def generate_excerpt
    # Take first 300 characters and find the last complete sentence
    truncated = content.strip.gsub(/<[^>]*>/, '').truncate(300)
    last_period = truncated.rindex('.')
    
    if last_period && last_period > 50
      self.excerpt = truncated[0..last_period]
    else
      self.excerpt = truncated
    end
  end
  
  def generate_meta_fields
    if meta_title.blank?
      self.meta_title = title.truncate(60)
    end
    
    if meta_description.blank?
      self.meta_description = excerpt.presence || content.strip.gsub(/<[^>]*>/, '').truncate(160)
    end
  end
end

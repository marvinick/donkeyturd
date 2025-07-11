class BlogController < ApplicationController
  before_action :set_blog_post, only: [:show]
  
  def index
    @blog_posts = BlogPost.published
                         .includes(:user)
                         .recent
                         .page(params[:page])
                         .per(10)
    
    @featured_posts = BlogPost.published.featured.limit(3)
    
    @meta_title = "Travel Guides & City Spotlights - Amazing Views Blog"
    @meta_description = "Discover the best scenic destinations and accommodations with our expert travel guides. Get insider tips on finding properties with breathtaking views."
  end
  
  def show
    unless @blog_post.published?
      redirect_to blog_index_path, alert: "Post not found."
      return
    end
    
    @related_posts = BlogPost.published
                            .where.not(id: @blog_post.id)
                            .recent
                            .limit(3)
    
    @meta_title = @blog_post.seo_title
    @meta_description = @blog_post.seo_description
  end
  
  private
  
  def set_blog_post
    @blog_post = BlogPost.find_by!(slug: params[:id])
  end
end

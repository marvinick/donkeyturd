module Admin
  class BlogPostsController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_admin_user
    before_action :set_blog_post, only: [:show, :edit, :update, :destroy, :publish, :unpublish, :toggle_featured]
    
    def index
      @blog_posts = BlogPost.includes(:user)
                           .order(created_at: :desc)
                           .page(params[:page])
                           .per(20)
      
      @published_count = BlogPost.published.count
      @draft_count = BlogPost.where(published: false).count
      @featured_count = BlogPost.featured.count
    end
    
    def show
      redirect_to edit_admin_blog_post_path(@blog_post)
    end
    
    def new
      @blog_post = current_user.blog_posts.build
    end
    
    def create
      @blog_post = current_user.blog_posts.build(blog_post_params)
      
      if @blog_post.save
        redirect_to admin_blog_posts_path, notice: 'Blog post was successfully created.'
      else
        render :new
      end
    end
    
    def edit
    end
    
    def update
      if @blog_post.update(blog_post_params)
        redirect_to admin_blog_posts_path, notice: 'Blog post was successfully updated.'
      else
        render :edit
      end
    end
    
    def destroy
      @blog_post.destroy
      redirect_to admin_blog_posts_path, notice: 'Blog post was successfully deleted.'
    end
    
    def publish
      @blog_post.publish!
      redirect_to admin_blog_posts_path, notice: 'Blog post was successfully published.'
    end
    
    def unpublish
      @blog_post.unpublish!
      redirect_to admin_blog_posts_path, notice: 'Blog post was successfully unpublished.'
    end
    
    def toggle_featured
      @blog_post.toggle_featured!
      status = @blog_post.featured? ? 'featured' : 'unfeatured'
      redirect_to admin_blog_posts_path, notice: "Blog post was successfully #{status}."
    end
    
    private
    
    def set_blog_post
      @blog_post = BlogPost.find_by!(slug: params[:id])
    end
    
    def blog_post_params
      params.require(:blog_post).permit(:title, :slug, :content, :excerpt, :meta_title, :meta_description, :published, :featured, images: [])
    end
    
    def ensure_admin_user
      redirect_to root_path unless current_user.admin?
    end
  end
end
